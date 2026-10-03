import MechanicsCore
import MechanicsModel
import MechanicsJoints
import MechanicsLoads
import MechanicsNumerics
public struct RigidEquationKernel: RigidEquationComputing {
    public init() {}
    public func assemble(_ input: RigidDynamicsInput, admission: DynamicsAdmission, loadWork: inout LoadWork, work: inout NumericalWork) throws(DynamicsError) -> RigidDynamicsSystem {
        try validate(input,admission:admission,work:&work)
        let n = input.velocity.count
        let matrixCount = try DynamicsArithmetic.product(n,n)
        let systemStorage = try DynamicsArithmetic.sum(matrixCount,DynamicsArithmetic.product(6,n))
        try DynamicsArithmetic.storage(DynamicsArithmetic.sum(systemStorage,DynamicsArithmetic.product(6,n)),&work)
        var mass = [Double](repeating:0,count:matrixCount), bias = [Double](repeating:0,count:n)
        var columns = [SpatialMotion](repeating:FrameMotion.zeroMotion,count:n)
        var forces = ForceAccumulator(count:n), gravityPotential = 0.0, gravityTimeDerivative = 0.0
        for bodyIndex in input.inertias.indices {
            try checkpoint(admission)
            let body = try WorldRigidBody.evaluate(input,index:bodyIndex,work:&work)
            let original = try geometricColumns(input,index:bodyIndex)
            for (i,column) in original.enumerated() { columns[i] = try body.comColumn(column,work:&work) }
            let momentum = try DynamicsArithmetic.apply(body.inertia,body.omega,&work)
            let torqueBias = try DynamicsArithmetic.add(DynamicsArithmetic.apply(body.inertia,body.angularBias,&work),DynamicsArithmetic.cross(body.omega,momentum,&work),&work)
            let forceBias = try DynamicsArithmetic.scale(body.accelerationBias,body.mass,&work)
            for j in 0..<n {
                try checkpoint(admission)
                let inertiaColumn = try DynamicsArithmetic.apply(body.inertia,columns[j].angular,&work)
                for i in 0...j {
                    let angular = try DynamicsArithmetic.dot(columns[i].angular,inertiaColumn,&work)
                    let linear = try DynamicsArithmetic.dot(columns[i].linear,columns[j].linear,&work)
                    try DynamicsArithmetic.operations(3,&work)
                    mass[i*n+j] = try DynamicsArithmetic.finite(mass[i*n+j]+angular+body.mass*linear)
                }
                try DynamicsArithmetic.operations(2,&work)
                bias[j] = try DynamicsArithmetic.finite(bias[j]+DynamicsArithmetic.dot(columns[j].angular,torqueBias,&work)+DynamicsArithmetic.dot(columns[j].linear,forceBias,&work))
            }
            if let field = input.gravity {
                // Loads logical evaluation cost remains in its caller-owned ledger; this point contract allocates no numerical arrays.
                let response: GravityResponse
                do { response = try GravityEvaluator().point(field,body:input.inertias[bodyIndex].body,
                    sample:GravitySample(point:body.position,mass:body.mass),work:&loadWork) } catch { throw .loads(error) }
                guard let energy = response.load.potentialEnergy else { throw .energyUnavailable }
                try DynamicsArithmetic.operations(2,&work)
                gravityPotential = try DynamicsArithmetic.finite(gravityPotential+energy)
                gravityTimeDerivative = try DynamicsArithmetic.finite(gravityTimeDerivative+response.explicitPotentialTimeDerivative)
                let force = response.load.forces.conservative
                for i in 0..<n {
                    try DynamicsArithmetic.operations(1,&work)
                    forces.gravity[i] = try DynamicsArithmetic.finite(forces.gravity[i]+DynamicsArithmetic.dot(columns[i].linear,force,&work))
                }
                let actual = try DynamicsArithmetic.dot(force,body.velocity,&work), prescribed = try DynamicsArithmetic.dot(force,body.drift.linear,&work)
                try accumulatePower(actual:actual,prescribed:prescribed,forces:&forces,work:&work)
            }
        }
        for i in 0..<n { for j in 0..<i { mass[i*n+j] = mass[j*n+i] } }
        var potential: Double? = 0, dissipation: Double? = 0
        for contribution in input.bodyWrenches {
            try checkpoint(admission)
            let index = try bodyIndex(input,contribution.body)
            let state = input.snapshot.bodies[index], original = try geometricColumns(input,index:index)
            let wrench = try worldWrench(contribution,state:state,work:&work)
            for (i,column) in original.enumerated() {
                try DynamicsArithmetic.operations(2,&work)
                let load = try DynamicsArithmetic.finite(DynamicsArithmetic.dot(wrench.torque,column.angular,&work)+DynamicsArithmetic.dot(wrench.force,column.linear,&work))
                try forces.add(load,at:i,channel:contribution.channel)
            }
            let actual = try wrenchPower(wrench,state.motion.velocity,work:&work)
            let prescribed = try wrenchPower(wrench,state.prescribedDriftVelocity,work:&work)
            try accumulatePower(actual:actual,prescribed:prescribed,forces:&forces,work:&work)
            try appendAvailability(contribution.potentialEnergy,into:&potential,work:&work)
            try appendAvailability(contribution.dissipatedPower,into:&dissipation,work:&work)
        }
        for contribution in input.generalizedForces {
            try checkpoint(admission)
            var power = 0.0
            for i in 0..<n {
                try DynamicsArithmetic.operations(3,&work)
                try forces.add(contribution.values[i],at:i,channel:contribution.channel)
                power = try DynamicsArithmetic.finite(power+contribution.values[i]*input.velocity[i])
            }
            try accumulatePower(actual:power,prescribed:0,forces:&forces,work:&work)
            try appendAvailability(contribution.potentialEnergy,into:&potential,work:&work)
            try appendAvailability(contribution.dissipatedPower,into:&dissipation,work:&work)
        }
        try checkpoint(admission)
        return RigidDynamicsSystem(input:input,massMatrix:mass,inertialBias:bias,forces:forces.result(),gravityPotential:gravityPotential,gravityExplicitPotentialTimeDerivative:gravityTimeDerivative,
            knownLoadPotential:potential,knownDissipatedPower:dissipation,assemblyWork:work,assemblyLoadWork:loadWork,scalarStorage:systemStorage,admission:admission)
    }
    public func originalInertialForce(_ system: RigidDynamicsSystem, acceleration: [Double], includeBias: Bool,
                                      into output: inout [Double], work: inout NumericalWork) throws(DynamicsError) {
        try validateAcceleration(acceleration,count:system.velocityCount)
        guard output.count == system.velocityCount else { throw .invalidShape }
        try DynamicsArithmetic.storage(DynamicsArithmetic.sum(system.scalarStorage,output.count),&work)
        for i in output.indices { output[i] = 0 }
        for index in system.input.inertias.indices {
            try checkpoint(system.admission)
            let body = try WorldRigidBody.evaluate(system.input,index:index,work:&work)
            let columns = try geometricColumns(system.input,index:index)
            let required = try body.required(acceleration,columns:columns,includeBias:includeBias,work:&work)
            for (i,column) in columns.enumerated() {
                let com = try body.comColumn(column,work:&work)
                try DynamicsArithmetic.operations(2,&work)
                output[i] = try DynamicsArithmetic.finite(output[i]+DynamicsArithmetic.dot(required.torque,com.angular,&work)+DynamicsArithmetic.dot(required.force,com.linear,&work))
            }
        }
        try checkpoint(system.admission)
    }
    public func inertialWrench(_ system: RigidDynamicsSystem, body id: EntityID, acceleration: [Double],
                               referencePointWorld: Vector3, work: inout NumericalWork) throws(DynamicsError) -> BodyWrenchEvidence {
        try validateAcceleration(acceleration,count:system.velocityCount); try checkpoint(system.admission)
        try DynamicsArithmetic.storage(system.scalarStorage,&work)
        let index = try bodyIndex(system.input,id), body = try WorldRigidBody.evaluate(system.input,index:index,work:&work)
        let wrench = try body.required(acceleration,columns:geometricColumns(system.input,index:index),includeBias:true,work:&work)
        let torque = try DynamicsArithmetic.add(wrench.torque,DynamicsArithmetic.cross(DynamicsArithmetic.subtract(body.position,referencePointWorld,&work),wrench.force,&work),&work)
        return BodyWrenchEvidence(body:id,frame:system.input.snapshot.tree.worldFrame,referencePoint:referencePointWorld,wrench:SpatialWrench(torque:torque,force:wrench.force))
    }
    public func energy(_ system: RigidDynamicsSystem, acceleration: [Double], angularMomentumReference: Vector3,
                       requireComplete: Bool, work: inout NumericalWork) throws(DynamicsError) -> MechanicalEnergy {
        try validateAcceleration(acceleration,count:system.velocityCount)
        try DynamicsArithmetic.storage(system.scalarStorage,&work)
        if requireComplete && (system.knownLoadPotential == nil || system.knownDissipatedPower == nil) { throw .energyUnavailable }
        var kinetic = 0.0, linearMomentum = Vector3.zero, angularMomentum = Vector3.zero
        var kineticRate = 0.0, prescribedPower = 0.0
        for index in system.input.inertias.indices {
            try checkpoint(system.admission)
            let body = try WorldRigidBody.evaluate(system.input,index:index,work:&work)
            let linear = try DynamicsArithmetic.scale(body.velocity,body.mass,&work), spin = try DynamicsArithmetic.apply(body.inertia,body.omega,&work)
            linearMomentum = try DynamicsArithmetic.add(linearMomentum,linear,&work)
            angularMomentum = try DynamicsArithmetic.add(angularMomentum,DynamicsArithmetic.add(spin,DynamicsArithmetic.cross(DynamicsArithmetic.subtract(body.position,angularMomentumReference,&work),linear,&work),&work),&work)
            try DynamicsArithmetic.operations(3,&work)
            kinetic = try DynamicsArithmetic.finite(kinetic+(DynamicsArithmetic.dot(body.velocity,linear,&work)+DynamicsArithmetic.dot(body.omega,spin,&work))/2)
            let required = try body.required(acceleration,columns:geometricColumns(system.input,index:index),includeBias:true,work:&work)
            let power = try wrenchPower(required,SpatialMotion(angular:body.omega,linear:body.velocity),work:&work)
            let driftPower = try wrenchPower(required,body.drift,work:&work)
            try DynamicsArithmetic.operations(2,&work)
            kineticRate = try DynamicsArithmetic.finite(kineticRate+power); prescribedPower = try DynamicsArithmetic.finite(prescribedPower+driftPower)
        }
        let potential: Double?
        if let known = system.knownLoadPotential { try DynamicsArithmetic.operations(1,&work); potential = try DynamicsArithmetic.finite(system.gravityPotential+known) } else { potential = nil }
        try DynamicsArithmetic.operations(1,&work); let virtual = try DynamicsArithmetic.finite(kineticRate-prescribedPower)
        try checkpoint(system.admission)
        return MechanicalEnergy(time:system.input.snapshot.time,frame:system.input.snapshot.tree.worldFrame,
            angularMomentumReference:angularMomentumReference,gravityExplicitPotentialTimeDerivative:system.gravityExplicitPotentialTimeDerivative,kineticEnergy:kinetic,potentialEnergy:potential,
            dissipatedPower:system.knownDissipatedPower,linearMomentum:linearMomentum,angularMomentum:angularMomentum,
            kineticEnergyRate:kineticRate,requiredVirtualPower:virtual,requiredPrescribedPower:prescribedPower)
    }
    private func validate(_ input: RigidDynamicsInput, admission: DynamicsAdmission, work: inout NumericalWork) throws(DynamicsError) {
        try checkpoint(admission)
        let n = input.snapshot.tree.layout.velocityCount, count = input.snapshot.bodies.count, limits = admission.capacity
        guard count <= limits.maximumBodies, n <= limits.maximumVelocities, input.bodyWrenches.count <= limits.maximumBodyWrenches,
              input.generalizedForces.count <= limits.maximumGeneralizedContributions else { throw .capacityExceeded }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar and zero-velocity query domains are not implemented. Assembly rejects them until corresponding mechanics/query evidence exists; the initial spatial dense profile must not qualify those domains.
        guard n > 0, input.snapshot.tree.bodies.allSatisfy({ $0.dimension == .spatial }) else { throw .unsupportedDomain }
        guard input.velocity.count == n, input.inertias.count == count else { throw .invalidShape }
        if let gravity = input.gravity {
            guard gravity.frame == input.snapshot.tree.worldFrame else { throw .frameMismatch }
            // FIXME(INCOMPLETE_IMPLEMENTATION): Nonuniform gravity distribution is not implemented. COM-only force would omit second-moment torque/potential; this assembly path fails until distributed field mechanics has independent evidence.
            guard gravity.gradient == .zero else { throw .unsupportedDomain }
        }
        for index in input.inertias.indices {
            try checkpoint(admission)
            let state = input.snapshot.bodies[index], inertia = input.inertias[index]
            guard inertia.body == state.body, inertia.frame == state.bodyFrame else { throw .inertiaIdentityMismatch }
            var angular = state.prescribedDriftVelocity.angular, linear = state.prescribedDriftVelocity.linear
            for (i,column) in try geometricColumns(input,index:index).enumerated() {
                angular = try DynamicsArithmetic.add(angular,DynamicsArithmetic.scale(column.angular,input.velocity[i],&work),&work)
                linear = try DynamicsArithmetic.add(linear,DynamicsArithmetic.scale(column.linear,input.velocity[i],&work),&work)
            }
            guard try agrees(angular,state.motion.velocity.angular,tolerance:admission.angularVelocityTolerance),
                  try agrees(linear,state.motion.velocity.linear,tolerance:admission.linearVelocityTolerance) else { throw .velocityMismatch }
        }
        for contribution in input.generalizedForces { try DynamicsArithmetic.operations(1,&work); guard contribution.values.count == n else { throw .invalidShape } }
    }
    private func agrees(_ a: Vector3, _ b: Vector3, tolerance: NumericalTolerance) throws(DynamicsError) -> Bool {
        try DynamicsArithmetic.core { () throws(CoreError) in
            let x = try tolerance.contains(error:a.x-b.x,scale:max(abs(a.x),abs(b.x)))
            let y = try tolerance.contains(error:a.y-b.y,scale:max(abs(a.y),abs(b.y)))
            let z = try tolerance.contains(error:a.z-b.z,scale:max(abs(a.z),abs(b.z)))
            return x && y && z
        }
    }
    private func geometricColumns(_ input: RigidDynamicsInput, index: Int) throws(DynamicsError) -> ArraySlice<SpatialMotion> {
        do { return try input.snapshot.geometricColumns(body:input.inertias[index].body) } catch { throw .joints(error) }
    }
    private func bodyIndex(_ input: RigidDynamicsInput, _ id: EntityID) throws(DynamicsError) -> Int {
        do { return try input.snapshot.tree.bodyIndex(id) } catch { throw .joints(error) }
    }
    private func worldWrench(_ load: BodyWrenchContribution, state: BodyKinematics, work: inout NumericalWork) throws(DynamicsError) -> SpatialWrench {
        let force: Vector3, torque: Vector3, point: Vector3
        if load.frame == state.worldFrame { force = load.wrench.force; torque = load.wrench.torque; point = load.referencePoint }
        else if load.frame == state.bodyFrame {
            let r = try DynamicsArithmetic.rotation(state.motion.pose.rotation,&work)
            force = try DynamicsArithmetic.apply(r,load.wrench.force,&work); torque = try DynamicsArithmetic.apply(r,load.wrench.torque,&work)
            point = try DynamicsArithmetic.add(state.motion.pose.translation,DynamicsArithmetic.apply(r,load.referencePoint,&work),&work)
        } else { throw .frameMismatch }
        let shifted = try DynamicsArithmetic.add(torque,DynamicsArithmetic.cross(DynamicsArithmetic.subtract(point,state.motion.pose.translation,&work),force,&work),&work)
        return SpatialWrench(torque:shifted,force:force)
    }
    private func wrenchPower(_ wrench: SpatialWrench, _ velocity: SpatialMotion, work: inout NumericalWork) throws(DynamicsError) -> Double {
        try DynamicsArithmetic.operations(1,&work)
        return try DynamicsArithmetic.finite(DynamicsArithmetic.dot(wrench.torque,velocity.angular,&work)+DynamicsArithmetic.dot(wrench.force,velocity.linear,&work))
    }
    private func accumulatePower(actual: Double, prescribed: Double, forces: inout ForceAccumulator, work: inout NumericalWork) throws(DynamicsError) {
        try DynamicsArithmetic.operations(4,&work)
        forces.actualPower = try DynamicsArithmetic.finite(forces.actualPower+actual)
        forces.prescribedPower = try DynamicsArithmetic.finite(forces.prescribedPower+prescribed)
        forces.virtualPower = try DynamicsArithmetic.finite(forces.virtualPower+actual-prescribed)
    }
    private func appendAvailability(_ value: Double?, into sum: inout Double?, work: inout NumericalWork) throws(DynamicsError) {
        if let existing = sum, let value { try DynamicsArithmetic.operations(1,&work); sum = try DynamicsArithmetic.finite(existing+value) } else { sum = nil }
    }
    private func validateAcceleration(_ values: [Double], count: Int) throws(DynamicsError) {
        guard values.count == count, values.allSatisfy({ $0.isFinite }) else { throw .invalidShape }
    }
    private func checkpoint(_ admission: DynamicsAdmission) throws(DynamicsError) {
        guard !admission.isCancelled(), !Task.isCancelled else { throw .cancelled }
    }
}
