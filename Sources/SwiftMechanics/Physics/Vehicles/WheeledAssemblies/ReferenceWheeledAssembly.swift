/// Selected six-body assembly. All histories and work are immutable or exclusive caller-owned values.
public struct ReferenceWheeledAssembly: WheeledAssemblyEvaluating, Sendable {
    public let equations: any RigidEquationComputing
    public let dynamics: any RigidDynamicsSolving
    public let loads: any ScalarLoadEvaluating
    public let drive: any DriveEvaluating
    public let transmission: any ActuationTransmitting
    public init(equations: any RigidEquationComputing, dynamics: any RigidDynamicsSolving,
                loads: any ScalarLoadEvaluating, drive: any DriveEvaluating, transmission: any ActuationTransmitting) {
        self.equations=equations; self.dynamics=dynamics; self.loads=loads; self.drive=drive; self.transmission=transmission
    }

    public func initialize(configuration c: WheeledAssemblyConfiguration, state: CompiledKinematicState,
                           steering: ActuatorState, work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyState {
        try admitArithmetic(&work)
        let model=c.model, tree=model.tree, t=c.topology
        // FIXME(INCOMPLETE_IMPLEMENTATION): General/four-wheel/prescribed-root vehicles reach admission here.
        // Only the documented floating six-body scalar tree has force, chart and history composition in this implementation.
        guard tree.rootBase == .spatialFloating, model.descriptor.rootAuthority == .dynamicState,
              tree.bodies.count == 6, tree.joints.count == 5, tree.layout.positionCount == 12,
              tree.layout.velocityCount == 11, model.descriptor.root == t.chassis,
              Set(tree.bodies.map { $0.id }) == Set([t.chassis,t.rearCarrier,t.rearWheel,t.frontCarrier,t.frontKnuckle,t.frontWheel]) else {
            throw .refusal(.unsupportedTopology)
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Constraint/extension vehicle assembly has no coupled solve here.
        // Initialize must refuse features/extensions until their actual force and evolution authority is composed.
        guard model.descriptor.features.isEmpty, model.descriptor.extensions.isEmpty else { throw .refusal(.unsupportedModelFeatures) }
        try WheeledAssemblySupplier.actuation { () throws(ActuationError) in
            try work.actuation.metadata(c.calibration.source); try work.actuation.metadata(model.stamp.identity)
        }
        let ids=[t.rearSuspension,t.frontSuspension,t.rearSpin,t.steering,t.frontSpin]
        let parents=[t.chassis,t.chassis,t.rearCarrier,t.frontCarrier,t.frontKnuckle]
        let children=[t.rearCarrier,t.frontCarrier,t.rearWheel,t.frontKnuckle,t.frontWheel]
        var positions:[Int]=[], velocities:[Int]=[], suspensionX:[Double]=[]
        for i in ids.indices {
            guard let joint=model.descriptor.joints.first(where: { $0.record.id == ids[i] }),
                  let layout=tree.layout.joints.first(where: { $0.joint == ids[i] }) else { throw .refusal(.unsupportedTopology) }
            let record=joint.record, axes=record.manifold.orderedAxes
            guard joint.authority == .dynamicState, record.parentBody == parents[i], record.childBody == children[i],
                  layout.positions.count == 1, layout.velocities.count == 1, axes.count == 1,
                  record.manifold.kind == (i < 2 ? .prismatic : .revolute),
                  axes[0].direction == (i < 2 || i == 3 ? .unitZ : .unitY),
                  case .fixed(let parentPose)=record.parentAnchor.placement,
                  case .fixed(let childPose)=record.childAnchor.placement,
                  parentPose.rotation == .identity, childPose.rotation == .identity else { throw .refusal(.unsupportedTopology) }
            if i < 2 {
                guard parentPose.translation.y == 0, childPose.translation == .zero else { throw .refusal(.unsupportedTopology) }
                suspensionX.append(parentPose.translation.x)
            } else {
                guard parentPose.translation == .zero, childPose.translation == .zero else { throw .refusal(.unsupportedTopology) }
            }
            positions.append(layout.positions.start); velocities.append(layout.velocities.start)
        }
        guard suspensionX[1] > suspensionX[0], c.rearSuspensionLaw.quadraticStiffness > 0 || c.rearSuspensionLaw.quarticStiffness > 0,
              c.frontSuspensionLaw.quadraticStiffness > 0 || c.frontSuspensionLaw.quarticStiffness > 0 else { throw .refusal(.outsideCalibration) }
        var inertias:[RigidBodyInertia]=[]
        for body in tree.bodies {
            guard let descriptor=model.descriptor.bodies.first(where: { $0.id == body.id }),
                  case .spatial(let record)=descriptor, record.mode == .dynamic, let inertia=record.inertia else { throw .refusal(.unsupportedTopology) }
            try WheeledAssemblySupplier.actuation { () throws(ActuationError) in
                try work.actuation.metadata(body.id.key); try work.actuation.metadata(inertia.provenance.source)
            }
            let admitted=try WheeledAssemblySupplier.dynamics(&work) { (_, _) throws(DynamicsError) in
                try RigidBodyInertia(body:record.id,frame:record.frame,properties:inertia.properties)
            }
            inertias.append(admitted)
        }
        let binding=c.steeringServo.binding
        try WheeledAssemblySupplier.actuation { () throws(ActuationError) in try binding.validate(model:model,work:&work.actuation) }
        guard binding.joint == t.steering, binding.coordinate == .rotation,
              binding.positionIndex == positions[3], binding.velocityIndex == velocities[3],
              c.steeringServo.positionGain > 0, steering.binding == binding, steering.mode == .position,
              steering.time == state.state.time else { throw .refusal(.staleState) }
        guard c.driveline.model == model.stamp, c.driveline.frame == tree.worldFrame,
              c.driveline.outputCoordinate == .rotation, c.driveline.prescribedRate == 0,
              c.driveline.gradient.count == 11, c.driveline.inputCoordinates.count == 11 else { throw .refusal(.outsideCalibration) }
        for i in 0..<11 {
            let kind:ScalarCoordinateKind=(i < 3 || i == velocities[0] || i == velocities[1]) ? .translation : .rotation
            guard c.driveline.inputCoordinates[i] == kind,
                  i == velocities[2] || i == velocities[4] || c.driveline.gradient[i] == 0 else { throw .refusal(.outsideCalibration) }
        }
        guard c.driveline.gradient[velocities[2]] != 0 || c.driveline.gradient[velocities[4]] != 0 else { throw .refusal(.outsideCalibration) }
        let accepted=WheeledAssemblyState(configuration:c,kinematic:state,steering:steering,sequence:0,
            cumulativeAbsoluteEnergyDefect:0,jointPositions:positions,jointVelocities:velocities,inertias:inertias)
        _=try snapshot(accepted,state:state,work:&work)
        try validateDomain(accepted,state:state.state)
        for i in 0..<2 {
            let law=i == 0 ? c.rearSuspensionLaw : c.frontSuspensionLaw
            _=try WheeledAssemblySupplier.loads { () throws(LoadError) in
                try loads.evaluate(law,coordinate:state.state.q[positions[i]],rate:state.state.v[velocities[i]],work:&work.loads)
            }
        }
        try work.check(); return accepted
    }

    public func query(state: WheeledAssemblyState, driver: WheeledAssemblyDriver, road: WheeledAssemblyRoadInput,
                      work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyEvaluation {
        try admitArithmetic(&work); try validateRoadTime(state,road:road,dt:0)
        let ports=try actuate(state,driver:driver,dt:0,work:&work)
        return try mechanics(state,kinematic:state.kinematic,ports:ports,road:road,work:&work)
    }

    public func step(state: WheeledAssemblyState, driver: WheeledAssemblyDriver, road: WheeledAssemblyRoadInput,
                     dt: Double, work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyStepReceipt {
        try admitArithmetic(&work)
        guard dt.isFinite, dt > 0, dt <= state.configuration.policy.maximumTimeStep else { throw .refusal(.outsideCalibration) }
        guard state.sequence < UInt64.max else { throw .refusal(.sequenceOverflow) }
        try validateRoadTime(state,road:road,dt:dt); try work.admitStep()
        let ports=try actuate(state,driver:driver,dt:dt,work:&work)
        let start=try mechanics(state,kinematic:state.kinematic,ports:ports,road:road,work:&work)
        let old=state.kinematic.state
        var q=old.q, v=old.v
        for i in q.indices where i < 3 || i >= 7 { q[i]=try finite(q[i]+dt*start.snapshot.coordinateRate[i]) }
        let rotation=try WheeledAssemblySupplier.core { () throws(CoreError) in
            try UnitQuaternion(w:old.q[3],x:old.q[4],y:old.q[5],z:old.q[6]).integratingBodyAngularVelocity(
                Vector3(old.v[3],old.v[4],old.v[5]),timeStep:dt)
        }
        q[3]=rotation.w; q[4]=rotation.x; q[5]=rotation.y; q[6]=rotation.z
        for i in v.indices { v[i]=try finite(v[i]+dt*start.solution.acceleration[i]) }
        let time=try finite(old.time+dt)
        guard time > old.time else { throw .refusal(.outsideCalibration) }
        let candidateRaw=try WheeledAssemblySupplier.joints { () throws(JointError) in
            try KinematicState(revision:old.revision,time:time,q:q,v:v,acceleration:[Double](repeating:0,count:11))
        }
        try validateDomain(state,state:candidateRaw)
        for (slot,torque) in [(2,ports.rearBrakeTorque),(4,ports.frontBrakeTorque)] where torque != 0 {
            let index=state.jointVelocities[slot]
            // FIXME(INCOMPLETE_IMPLEMENTATION): Applied dry braking reaches a spin reversal during this explicit step.
            // Event-localized stopping and a verified static brake reaction are required before such candidates can succeed.
            guard v[index] != 0, (v[index] > 0) == (old.v[index] > 0) else { throw .refusal(.brakeSpinCrossing) }
        }
        let candidate=try makeState(state,raw:candidateRaw,work:&work)
        let end=try mechanics(state,kinematic:candidate,ports:ports,road:road,work:&work)
        let roadWork=try trapezoid(start.roadPower,end.roadPower,dt:dt)
        let motorWork=try trapezoid(start.motorPower,end.motorPower,dt:dt)
        let steeringWork=try trapezoid(start.steeringPower,end.steeringPower,dt:dt)
        let brakeLoss=try trapezoid(start.brakeLossPower,end.brakeLossPower,dt:dt)
        let suspensionLoss=try trapezoid(start.suspensionLossPower,end.suspensionLossPower,dt:dt)
        let delta=try finite(end.storedEnergy-start.storedEnergy)
        let steeringSourceWork=ports.steering.energy.sourceWork
        let steeringQuadratureDifference=try finite(steeringWork-ports.steering.energy.mechanicalWork)
        let residual=try finite(delta-roadWork-motorWork-steeringSourceWork+brakeLoss+suspensionLoss)
        let energyScale=max(abs(start.storedEnergy),max(abs(end.storedEnergy),abs(roadWork)+abs(motorWork)+abs(steeringSourceWork)+brakeLoss+suspensionLoss))
        try gate(residual,scale:energyScale,tolerance:state.configuration.policy.energyTolerance,reason:.energyResidual)
        let cumulative=try finite(state.cumulativeAbsoluteEnergyDefect+abs(residual))
        guard cumulative <= state.configuration.policy.maximumCumulativeEnergyDefect else { throw .refusal(.cumulativeEnergyDefect) }
        let linearImpulse=try WheeledAssemblySupplier.core { () throws(CoreError) in try start.externalForce.adding(end.externalForce).scaled(by:dt/2) }
        let angularImpulse=try WheeledAssemblySupplier.core { () throws(CoreError) in try start.externalTorqueAtWorldOrigin.adding(end.externalTorqueAtWorldOrigin).scaled(by:dt/2) }
        let linear=try WheeledAssemblySupplier.core { () throws(CoreError) in try end.energy.linearMomentum.subtracting(start.energy.linearMomentum).subtracting(linearImpulse) }
        let angular=try WheeledAssemblySupplier.core { () throws(CoreError) in try end.energy.angularMomentum.subtracting(start.energy.angularMomentum).subtracting(angularImpulse) }
        try vectorGate(linear,start:start.energy.linearMomentum,end:end.energy.linearMomentum,impulse:linearImpulse,tolerance:state.configuration.policy.linearMomentumTolerance,reason:.linearMomentum)
        try vectorGate(angular,start:start.energy.angularMomentum,end:end.energy.angularMomentum,impulse:angularImpulse,tolerance:state.configuration.policy.angularMomentumTolerance,reason:.angularMomentum)
        try work.check()
        let accepted=WheeledAssemblyState(configuration:state.configuration,kinematic:end.kinematic,steering:ports.steering.state,
            sequence:state.sequence+1,cumulativeAbsoluteEnergyDefect:cumulative,jointPositions:state.jointPositions,
            jointVelocities:state.jointVelocities,inertias:state.inertias)
        return WheeledAssemblyStepReceipt(state:accepted,start:start,end:end,estimatedRoadWork:roadWork,estimatedMotorWork:motorWork,
            estimatedSteeringWork:steeringWork,estimatedBrakeLoss:brakeLoss,estimatedSuspensionLoss:suspensionLoss,
            energyResidual:residual,originalSteeringSourceWork:steeringSourceWork,
            steeringWorkQuadratureDifference:steeringQuadratureDifference,linearMomentumResidual:linear,angularMomentumResidual:angular)
    }

    private func actuate(_ state: WheeledAssemblyState, driver: WheeledAssemblyDriver, dt: Double,
                         work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyActuation {
        let c=state.configuration, raw=state.kinematic.state, positions=state.jointPositions, velocities=state.jointVelocities
        try validateDomain(state,state:raw)
        guard abs(driver.steeringAngle) <= c.policy.maximumSteeringAngle else { throw .refusal(.outsideCalibration) }
        let steering=try WheeledAssemblySupplier.actuation { () throws(ActuationError) in
            try drive.step(law:c.steeringServo,state:state.steering,
                sample:ActuatorSample(binding:c.steeringServo.binding,time:raw.time,position:raw.q[positions[3]],velocity:raw.v[velocities[3]]),
                command:DriveCommand(mode:.position,value:driver.steeringAngle),dt:dt,energyTolerance:c.policy.energyTolerance,
                work:&work.actuation,numerical:&work.numerical)
        }
        let shaft=try finite(driver.throttle*c.maximumShaftEffort)
        let transmitted=try WheeledAssemblySupplier.actuation { () throws(ActuationError) in
            try transmission.affine(c.driveline,model:c.model.stamp,frame:c.model.tree.worldFrame,effort:shaft,
                rate:raw.v,tolerance:c.policy.powerTolerance,work:&work.actuation,numerical:&work.numerical)
        }
        guard transmitted.efforts.count == 11, transmitted.efforts.allSatisfy({ $0.isFinite }),
              transmitted.prescribedPower == 0 else { throw .refusal(.invalidInput) }
        let rear=try brake(driver.rearBrake*c.maximumRearBrakeTorque,spin:raw.v[velocities[2]])
        let front=try brake(driver.frontBrake*c.maximumFrontBrakeTorque,spin:raw.v[velocities[4]])
        var efforts=transmitted.efforts
        efforts[velocities[3]]=try finite(efforts[velocities[3]]+steering.appliedEffort)
        efforts[velocities[2]]=try finite(efforts[velocities[2]]+rear)
        efforts[velocities[4]]=try finite(efforts[velocities[4]]+front)
        return WheeledAssemblyActuation(steering:steering,driveline:transmitted,rearBrakeTorque:rear,frontBrakeTorque:front,efforts:efforts)
    }

    private func mechanics(_ owner: WheeledAssemblyState, kinematic: CompiledKinematicState, ports: WheeledAssemblyActuation,
                           road: WheeledAssemblyRoadInput, work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> WheeledAssemblyEvaluation {
        let c=owner.configuration, raw=kinematic.state
        try validateDomain(owner,state:raw)
        let original=try snapshot(owner,state:kinematic,work:&work)
        try validateRoad(owner,snapshot:original,road:road,work:&work)
        let rear=try WheeledAssemblySupplier.loads { () throws(LoadError) in
            try loads.evaluate(c.rearSuspensionLaw,coordinate:raw.q[owner.jointPositions[0]],rate:raw.v[owner.jointVelocities[0]],work:&work.loads)
        }
        let front=try WheeledAssemblySupplier.loads { () throws(LoadError) in
            try loads.evaluate(c.frontSuspensionLaw,coordinate:raw.q[owner.jointPositions[1]],rate:raw.v[owner.jointVelocities[1]],work:&work.loads)
        }
        guard let rearPotential=rear.potentialEnergy, let frontPotential=front.potentialEnergy else { throw .refusal(.invalidInput) }
        let springPotential=try finite(rearPotential+frontPotential), suspensionLoss=try finite(rear.dissipatedPower+front.dissipatedPower)
        var suspension=[Double](repeating:0,count:11)
        suspension[owner.jointVelocities[0]]=try WheeledAssemblySupplier.loads { () throws(LoadError) in try rear.total() }
        suspension[owner.jointVelocities[1]]=try WheeledAssemblySupplier.loads { () throws(LoadError) in try front.total() }
        let brakePower=try finite(ports.rearBrakeTorque*raw.v[owner.jointVelocities[2]]+ports.frontBrakeTorque*raw.v[owner.jointVelocities[4]])
        guard brakePower <= 0 else { throw .refusal(.brakeSpinCrossing) }
        let input=try WheeledAssemblySupplier.dynamics(&work) { (_, _) throws(DynamicsError) in
            try RigidDynamicsInput(snapshot:original,velocity:raw.v,inertias:owner.inertias,gravity:c.gravity,bodyWrenches:[road.rear,road.front],
                generalizedForces:[GeneralizedForceContribution(values:suspension,channel:.applied,potentialEnergy:springPotential,dissipatedPower:suspensionLoss),
                    GeneralizedForceContribution(values:ports.efforts,channel:.actuator,potentialEnergy:0,dissipatedPower:-brakePower)])
        }
        let system=try WheeledAssemblySupplier.dynamics(&work) { (loadWork,numerical) throws(DynamicsError) in
            try equations.assemble(input,admission:c.policy.dynamicsAdmission,loadWork:&loadWork,work:&numerical)
        }
        let solution=try WheeledAssemblySupplier.dynamics(&work) { (_, numerical) throws(DynamicsError) in
            try dynamics.forward(system,driveForce:[Double](repeating:0,count:11),policy:c.policy.dynamicsSolve,work:&numerical)
        }
        guard solution.acceleration.count == 11, solution.originalPhysicalResidual.isAccepted else { throw .refusal(.invalidInput) }
        let energy=try WheeledAssemblySupplier.dynamics(&work) { (_, numerical) throws(DynamicsError) in
            try equations.energy(system,acceleration:solution.acceleration,angularMomentumReference:.zero,requireComplete:false,work:&numerical)
        }
        let wrench=try WheeledAssemblySupplier.dynamics(&work) { (_, numerical) throws(DynamicsError) in
            try equations.inertialWrench(system,body:c.topology.chassis,acceleration:solution.acceleration,referencePointWorld:.zero,work:&numerical)
        }
        let physicalRaw=try WheeledAssemblySupplier.joints { () throws(JointError) in
            try KinematicState(revision:raw.revision,time:raw.time,q:raw.q,v:raw.v,acceleration:solution.acceleration)
        }
        let physical=try makeState(owner,raw:physicalRaw,work:&work)
        let physicalSnapshot=try snapshot(owner,state:physical,work:&work)
        let roadPower=try finite(wrenchPower(road.rear,snapshot:original)+wrenchPower(road.front,snapshot:original))
        var motorPower=0.0
        for i in raw.v.indices { motorPower=try finite(motorPower+ports.driveline.efforts[i]*raw.v[i]) }
        let steeringPower=try finite(ports.steering.appliedEffort*raw.v[owner.jointVelocities[3]])
        var gravityPower=0.0
        for inertia in owner.inertias {
            let body=try WheeledAssemblySupplier.joints { () throws(JointError) in try original.body(inertia.body) }
            let power=try WheeledAssemblySupplier.core { () throws(CoreError) in
                let offset=try body.motion.pose.rotation.rotating(inertia.properties.centerOfMass)
                let velocity=try body.motion.velocity.linear.adding(body.motion.velocity.angular.cross(offset))
                return try c.gravity.accelerationAtOrigin.scaled(by:inertia.properties.mass).dot(velocity)
            }
            gravityPower=try finite(gravityPower+power)
        }
        let suspensionPower=try finite(suspension[owner.jointVelocities[0]]*raw.v[owner.jointVelocities[0]]
            + suspension[owner.jointVelocities[1]]*raw.v[owner.jointVelocities[1]])
        let portPower=try finite(roadPower+motorPower+steeringPower+brakePower+suspensionPower+gravityPower)
        try gate(try finite(system.forces.actualPower-portPower),scale:max(abs(system.forces.actualPower),abs(portPower)),
            tolerance:c.policy.powerTolerance,reason:.instantaneousPower)
        let residual=try finite(energy.kineticEnergyRate-system.forces.actualPower)
        try gate(residual,scale:max(abs(energy.kineticEnergyRate),abs(system.forces.actualPower)),tolerance:c.policy.powerTolerance,reason:.instantaneousPower)
        let external=try externalWrench(owner,snapshot:original,road:road)
        let stored=try finite(energy.kineticEnergy+system.gravityPotential+springPotential)
        try work.check()
        return WheeledAssemblyEvaluation(kinematic:physical,snapshot:physicalSnapshot,solution:solution,energy:energy,chassisInertialWrench:wrench,
            rearSuspension:rear,frontSuspension:front,actuation:ports,roadSource:road.source,
            suppliedRearNormalForce:road.rear.wrench.force.z,suppliedFrontNormalForce:road.front.wrench.force.z,
            storedEnergy:stored,roadPower:roadPower,motorPower:motorPower,steeringPower:steeringPower,brakeLossPower:-brakePower,
            suspensionLossPower:suspensionLoss,instantaneousPowerResidual:residual,externalForce:external.force,externalTorqueAtWorldOrigin:external.torque)
    }

    private func snapshot(_ owner: WheeledAssemblyState, state: CompiledKinematicState,
                          work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> KinematicSnapshot {
        try work.modelCall()
        return try WheeledAssemblySupplier.compilation { () throws(CompilationFailure) in try owner.configuration.model.evaluate(state) }
    }
    private func makeState(_ owner: WheeledAssemblyState, raw: KinematicState,
                           work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) -> CompiledKinematicState {
        try work.modelCall()
        return try WheeledAssemblySupplier.compilation { () throws(CompilationFailure) in try owner.configuration.model.makeState(raw) }
    }
    private func admitArithmetic(_ work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) {
        try work.check()
        // Conservative scalar capacity for two six-body snapshots/systems/receipts and all local fixed-shape arrays.
        // This is admitted capacity, not measured allocation or a replacement for suppliers' original work.
        try WheeledAssemblySupplier.numerical { () throws(NumericalError) in
            try work.numerical.requireStorage(8192); try work.numerical.chargeOperations(4096)
        }
    }
    private func validateDomain(_ owner: WheeledAssemblyState, state: KinematicState) throws(WheeledAssemblyFailure) {
        let p=owner.configuration.policy
        guard state.revision == owner.configuration.model.stamp.revision, state.q.count == 12, state.v.count == 11,
              state.prescribedAnchors.isEmpty, abs(state.q[owner.jointPositions[3]]) <= p.maximumSteeringAngle,
              abs(state.v[owner.jointVelocities[2]]) <= p.maximumWheelSpin,
              abs(state.v[owner.jointVelocities[4]]) <= p.maximumWheelSpin else { throw .refusal(.outsideCalibration) }
        let linear=try WheeledAssemblySupplier.core { () throws(CoreError) in try Vector3(state.v[0],state.v[1],state.v[2]).magnitude() }
        let angular=try WheeledAssemblySupplier.core { () throws(CoreError) in try Vector3(state.v[3],state.v[4],state.v[5]).magnitude() }
        guard linear <= p.maximumRootLinearSpeed, angular <= p.maximumRootAngularSpeed else { throw .refusal(.outsideCalibration) }
    }
    private func validateRoadTime(_ owner: WheeledAssemblyState, road: WheeledAssemblyRoadInput, dt: Double) throws(WheeledAssemblyFailure) {
        guard road.time == owner.kinematic.state.time, road.validUntil >= (try finite(road.time+dt)),
              owner.steering.time == owner.kinematic.state.time else { throw .refusal(.staleState) }
    }
    private func validateRoad(_ owner: WheeledAssemblyState, snapshot: KinematicSnapshot, road: WheeledAssemblyRoadInput,
                              work: inout WheeledAssemblyWork) throws(WheeledAssemblyFailure) {
        let c=owner.configuration, p=c.policy
        try WheeledAssemblySupplier.actuation { () throws(ActuationError) in try work.actuation.metadata(road.source.source) }
        for (load,body) in [(road.rear,c.topology.rearWheel),(road.front,c.topology.frontWheel)] {
            // FIXME(INCOMPLETE_IMPLEMENTATION): Arbitrary road/local-frame/potential-bearing ports are not composed here.
            // Only explicit held world contact wrenches with separately accounted interface work can succeed.
            guard load.body == body, load.frame == c.model.tree.worldFrame, load.channel == .contact,
                  load.potentialEnergy == nil, load.dissipatedPower == nil, load.wrench.force.z >= 0 else { throw .refusal(.unsupportedRoadPort) }
            let motion=try WheeledAssemblySupplier.joints { () throws(JointError) in try snapshot.body(body).motion }
            let force=try WheeledAssemblySupplier.core { () throws(CoreError) in try load.wrench.force.magnitude() }
            let torque=try WheeledAssemblySupplier.core { () throws(CoreError) in try load.wrench.torque.magnitude() }
            let arm=try WheeledAssemblySupplier.core { () throws(CoreError) in try load.referencePoint.subtracting(motion.pose.translation).magnitude() }
            guard force <= p.maximumRoadForce, torque <= p.maximumRoadTorque, arm <= p.maximumRoadLeverArm else { throw .refusal(.outsideCalibration) }
        }
    }
    private func wrenchPower(_ load: BodyWrenchContribution, snapshot: KinematicSnapshot) throws(WheeledAssemblyFailure) -> Double {
        let body=try WheeledAssemblySupplier.joints { () throws(JointError) in try snapshot.body(load.body) }
        return try WheeledAssemblySupplier.core { () throws(CoreError) in
            let velocity=try body.motion.velocity.linear.adding(body.motion.velocity.angular.cross(load.referencePoint.subtracting(body.motion.pose.translation)))
            return try load.wrench.power(against:SpatialMotion(angular:body.motion.velocity.angular,linear:velocity))
        }
    }
    private func externalWrench(_ owner: WheeledAssemblyState, snapshot: KinematicSnapshot,
                                road: WheeledAssemblyRoadInput) throws(WheeledAssemblyFailure) -> SpatialWrench {
        var force=try WheeledAssemblySupplier.core { () throws(CoreError) in try road.rear.wrench.force.adding(road.front.wrench.force) }
        var torque=try WheeledAssemblySupplier.core { () throws(CoreError) in
            try road.rear.wrench.torque.adding(road.rear.referencePoint.cross(road.rear.wrench.force))
                .adding(road.front.wrench.torque).adding(road.front.referencePoint.cross(road.front.wrench.force))
        }
        for inertia in owner.inertias {
            let body=try WheeledAssemblySupplier.joints { () throws(JointError) in try snapshot.body(inertia.body) }
            try WheeledAssemblySupplier.core { () throws(CoreError) in
                let gravity=try owner.configuration.gravity.accelerationAtOrigin.scaled(by:inertia.properties.mass)
                let com=try body.motion.pose.transforming(point:inertia.properties.centerOfMass)
                force=try force.adding(gravity); torque=try torque.adding(com.cross(gravity))
            }
        }
        return SpatialWrench(torque:torque,force:force)
    }
    private func brake(_ magnitude: Double, spin: Double) throws(WheeledAssemblyFailure) -> Double {
        let admitted=try finite(magnitude)
        if admitted == 0 { return 0 }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Dry brake commands at zero wheel spin have no static reaction solve.
        // Query/step must fail until event-localized stopping and actual holding reaction are implemented and verified.
        guard spin != 0 else { throw .refusal(.brakeAtZeroSpeed) }
        return spin > 0 ? -admitted : admitted
    }
    private func finite(_ value: Double) throws(WheeledAssemblyFailure) -> Double {
        guard value.isFinite else { throw .refusal(.invalidInput) }; return value
    }
    private func trapezoid(_ first: Double, _ second: Double, dt: Double) throws(WheeledAssemblyFailure) -> Double {
        try finite(dt*(first/2+second/2))
    }
    private func gate(_ residual: Double, scale: Double, tolerance: NumericalTolerance,
                      reason: WheeledAssemblyFailure.Refusal) throws(WheeledAssemblyFailure) {
        let accepted=try WheeledAssemblySupplier.core { () throws(CoreError) in try tolerance.contains(error:residual,scale:scale) }
        guard accepted else { throw .residual(kind:reason,value:residual,scale:scale) }
    }
    private func vectorGate(_ residual: Vector3, start: Vector3, end: Vector3, impulse: Vector3,
                            tolerance: NumericalTolerance, reason: WheeledAssemblyFailure.Refusal) throws(WheeledAssemblyFailure) {
        let error=try WheeledAssemblySupplier.core { () throws(CoreError) in try residual.magnitude() }
        let scale=try WheeledAssemblySupplier.core { () throws(CoreError) in max(try start.magnitude(),max(try end.magnitude(),try impulse.magnitude())) }
        try gate(error,scale:scale,tolerance:tolerance,reason:reason)
    }
}
