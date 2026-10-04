internal final class ToothContactPhysics: Sendable {
    let model: ToothContactModel
    let geometry: any CollisionGeometryQuerying
    let laws: any ContactLawEvaluating
    let dynamics: any RigidDynamicsSolving
    init(model: ToothContactModel, geometry: any CollisionGeometryQuerying, laws: any ContactLawEvaluating,
         dynamics: any RigidDynamicsSolving) { self.model=model; self.geometry=geometry; self.laws=laws; self.dynamics=dynamics }
    @inline(never)
    func history(time: Double, policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> [ContactHistory] {
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        try work.charge(try ToothArithmetic.product(128,model.contacts.count),storage:reserved)
        var histories:[ContactHistory]=[]; histories.reserveCapacity(model.contacts.count)
        for pair in model.contacts {
            let id=try identity(pair)
            let supplied=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
                try self.laws.initialHistory(identity:id,pair:pair.law,timeSeconds:time,work:&local)
            }
            let original=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
                try CompliantContactEvaluator().initialHistory(identity:id,pair:pair.law,timeSeconds:time,work:&local)
            }
            guard supplied == original else { throw .invalidSupplierOutput }; histories.append(supplied)
        }
        return histories
    }
    func identity(_ pair: ToothContactPair) throws(ToothContactError) -> ContactIdentity {
        let a=model.teeth[pair.firstProxy].proxy.geometry, b=model.teeth[pair.secondProxy].proxy.geometry
        do { return try ContactIdentity(key:pair.key,firstBody:ModelReference(id:a.bodyID,revision:model.tree.revision),
            secondBody:ModelReference(id:b.bodyID,revision:model.tree.revision),frame:ModelReference(id:model.tree.worldFrame,revision:model.tree.revision),
            firstGeometryRevision:a.geometryRevision,secondGeometryRevision:b.geometryRevision,tangentLayoutRevision:model.source.revision) }
        catch { throw .contact(error) }
    }
    @inline(never)
    func evaluate(state: KinematicState, histories: [ContactHistory], intervalStart: Double, timeStep: Double,
                  policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothPhysicalSample {
        try ToothArithmetic.check(policy)
        guard histories.count == model.contacts.count else { throw .staleSource }
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        try work.charge(try ToothArithmetic.product(512,model.contacts.count),storage:reserved)
        let snapshot=try ToothArithmetic.snapshot(model,state:state,policy:policy,work:&work)
        guard snapshot.coordinateRate == state.v else { throw .unsupportedDomain }
        var loads:[BodyWrenchContribution]=[], observations:[ToothContactObservation]=[], next:[ContactHistory]=[]
        loads.reserveCapacity(try ToothArithmetic.product(2,model.contacts.count))
        observations.reserveCapacity(model.contacts.count); next.reserveCapacity(model.contacts.count)
        var stored=0.0, loss=0.0, contactPower=0.0
        for i in model.contacts.indices {
            let sample=try pairSample(i,snapshot:snapshot,history:histories[i],start:intervalStart,step:timeStep,policy:policy,work:&work)
            loads.append(sample.firstLoad); loads.append(sample.secondLoad)
            observations.append(sample.observation); next.append(sample.observation.response.trialHistory)
            stored=try ToothArithmetic.value(stored+sample.observation.response.normalStoredEnergy)
            loss=try ToothArithmetic.value(loss+sample.observation.response.normalDissipationPower)
            contactPower=try ToothArithmetic.value(contactPower+sample.observation.response.relativeMechanicalPower)
        }
        return try mechanical(snapshot:snapshot,loads:loads,observations:observations,histories:next,stored:stored,loss:loss,
            contactPower:contactPower,reserved:reserved,policy:policy,work:&work)
    }
    @inline(never)
    private func pairSample(_ index: Int, snapshot: KinematicSnapshot, history: ContactHistory, start: Double, step: Double,
                            policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothPairSample {
        let pair=model.contacts[index], a=model.teeth[pair.firstProxy], b=model.teeth[pair.secondProxy]
        guard history.identity == (try identity(pair)), history.pair == pair.law, history.timeSeconds == start else { throw .staleSource }
        let first: BodyKinematics, second: BodyKinematics
        do { first=try snapshot.body(a.proxy.geometry.bodyID); second=try snapshot.body(b.proxy.geometry.bodyID) } catch { throw .joint(error) }
        let poseA=try ToothArithmetic.core { () throws(CoreError) in try first.motion.pose.composed(with:a.colliderToBody) }
        let poseB=try ToothArithmetic.core { () throws(CoreError) in try second.motion.pose.composed(with:b.colliderToBody) }
        let proxyA=a.proxy.moved(to:poseA), proxyB=b.proxy.moved(to:poseB)
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
        let witness=try ToothArithmetic.collision(reserved:reserved,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in
            try self.geometry.witness(first:proxyA,second:proxyB,policy:policy.collision,work:&local)
        }
        let original=try ToothArithmetic.collision(reserved:reserved,policy:policy,work:&work) { (local: inout CollisionWork) throws(CollisionError) in
            try AnalyticCollisionQueries().witness(first:proxyA,second:proxyB,policy:policy.collision,work:&local)
        }
        guard witness.pair == original.pair, witness.poseA == poseA, witness.poseB == poseB,
              witness.featureA == original.featureA, witness.featureB == original.featureB,
              witness.approximationError == original.approximationError else { throw .invalidSupplierOutput }
        guard witness.degeneracy == .regular, original.degeneracy == .regular else { throw .unsupportedDomain }
        try ToothArithmetic.vector(witness.pointA,original.pointA,policy:policy)
        try ToothArithmetic.vector(witness.pointB,original.pointB,policy:policy)
        let normalError=try ToothArithmetic.core { () throws(CoreError) in try witness.normal.subtracting(original.normal).magnitude() }
        guard normalError <= policy.collision.normalTolerance, abs(witness.separation-original.separation) <= policy.collision.lengthTolerance else { throw .invalidSupplierOutput }
        try work.charge(512)
        let ra=try ToothArithmetic.core { () throws(CoreError) in try witness.pointA.subtracting(first.motion.pose.translation) }
        let rb=try ToothArithmetic.core { () throws(CoreError) in try witness.pointB.subtracting(second.motion.pose.translation) }
        let va=try ToothArithmetic.core { () throws(CoreError) in try first.motion.velocity.linear.adding(first.motion.velocity.angular.cross(ra)) }
        let vb=try ToothArithmetic.core { () throws(CoreError) in try second.motion.velocity.linear.adding(second.motion.velocity.angular.cross(rb)) }
        let relative=try ToothArithmetic.core { () throws(CoreError) in try vb.subtracting(va) }
        let angular=try ToothArithmetic.core { () throws(CoreError) in try second.motion.velocity.angular.subtracting(first.motion.velocity.angular) }
        let rotation=try ToothArithmetic.core { () throws(CoreError) in
            if witness.normal.z == -1, witness.normal.x == 0, witness.normal.y == 0 { return try UnitQuaternion(axis:.unitX,angle:.pi) }
            return try UnitQuaternion(w:1+witness.normal.z,x:-witness.normal.y,y:witness.normal.x,z:0)
        }
        let basis: ContactBasis, input: ContactInput
        do { basis=try ContactBasis(frame:history.identity.frame,contactToQuery:rotation)
            input=try ContactInput(identity:history.identity,basis:basis,separation:witness.separation,
                relativeVelocity:relative,relativeAngularVelocity:angular,startTimeSeconds:start,timeStepSeconds:step) }
        catch { throw .contact(error) }
        let basisError=try ToothArithmetic.core { () throws(CoreError) in try basis.normal.subtracting(witness.normal).magnitude() }
        guard basisError <= policy.collision.normalTolerance else { throw .invalidSupplierOutput }
        let response=try lawResponse(input:input,pair:pair,history:history,policy:policy,reserved:reserved,work:&work)
        let forceA=try ToothArithmetic.core { () throws(CoreError) in try response.forceOnB.scaled(by:-1) }
        let ta=try ToothArithmetic.core { () throws(CoreError) in try ra.cross(forceA) }
        let tb=try ToothArithmetic.core { () throws(CoreError) in try rb.cross(response.forceOnB) }
        let vn=try ToothArithmetic.core { () throws(CoreError) in try witness.normal.dot(relative) }
        let slip=try ToothArithmetic.core { () throws(CoreError) in try relative.subtracting(witness.normal.scaled(by:vn)) }
        let loadA: BodyWrenchContribution, loadB: BodyWrenchContribution
        do {
            loadA=try BodyWrenchContribution(body:first.body,frame:model.tree.worldFrame,referencePoint:witness.pointA,
                wrench:SpatialWrench(torque:.zero,force:forceA),channel:.contact,potentialEnergy:response.normalStoredEnergy,dissipatedPower:response.normalDissipationPower)
            loadB=try BodyWrenchContribution(body:second.body,frame:model.tree.worldFrame,referencePoint:witness.pointB,
                wrench:SpatialWrench(torque:.zero,force:response.forceOnB),channel:.contact,potentialEnergy:0,dissipatedPower:0)
        } catch { throw .dynamics(error) }
        return ToothPairSample(observation:ToothContactObservation(pair:pair,witness:witness,relativePointVelocity:relative,slipVelocity:slip,
            response:response,forceOnA:forceA,forceOnB:response.forceOnB,torqueAtFirstBodyOrigin:ta,torqueAtSecondBodyOrigin:tb),firstLoad:loadA,secondLoad:loadB)
    }
    @inline(never)
    private func lawResponse(input: ContactInput, pair: ToothContactPair, history: ContactHistory, policy: ToothContactPolicy,
                             reserved: Int, work: inout ToothContactWork) throws(ToothContactError) -> ContactResponse {
        let response=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try self.laws.evaluate(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
        }
        let original=try ToothArithmetic.contact(reserved:reserved,policy:policy,work:&work) { (local: inout ContactWork) throws(ContactLawError) in
            try CompliantContactEvaluator().evaluate(input:input,pair:pair.law,accepted:history,policy:policy.contact,work:&local)
        }
        try work.charge(256)
        guard response.trialHistory == original.trialHistory, response.acceptedHistorySequence == original.acceptedHistorySequence,
              response.frictionRegime == .disabled, response.coupleOnB == .zero,
              response.cohesiveNormalForce == 0, response.tangentialForceFirst == 0, response.tangentialForceSecond == 0,
              response.tangentialStoredEnergy == 0, response.cohesivePotentialEnergy == 0,
              response.completeCohesiveSeparationWork == 0, response.resistanceDissipationPower == 0,
              response.tangentialDissipationEnergy == 0, response.frictionConeUtilization == 0 else { throw .invalidSupplierOutput }
        let energy=policy.dynamics.energyScale, length=model.jointPolicy.characteristicLengthMeters, power=energy/policy.dynamics.timeScale
        let forceError=try ToothArithmetic.core { () throws(CoreError) in try response.forceOnB.subtracting(original.forceOnB).magnitude() }
        try ToothArithmetic.close(forceError,0,scale:energy/length,policy:policy)
        try ToothArithmetic.close(response.compressiveNormalForce,original.compressiveNormalForce,scale:energy/length,policy:policy)
        try ToothArithmetic.close(response.normalStoredEnergy,original.normalStoredEnergy,scale:energy,policy:policy)
        try ToothArithmetic.close(response.normalDissipationPower,original.normalDissipationPower,scale:power,policy:policy)
        try ToothArithmetic.close(response.relativeMechanicalPower,original.relativeMechanicalPower,scale:power,policy:policy)
        try ToothArithmetic.close(response.normalForcePenetrationDerivative,original.normalForcePenetrationDerivative,scale:energy/(length*length),policy:policy)
        try ToothArithmetic.close(response.originalPowerResidual,original.originalPowerResidual,scale:power,policy:policy)
        guard response.normalForceVelocityDerivative == 0, response.originalTangentialEnergyResidual == 0 else { throw .invalidSupplierOutput }
        return response
    }
    @inline(never)
    private func mechanical(snapshot: KinematicSnapshot, loads: [BodyWrenchContribution], observations: [ToothContactObservation],
                            histories: [ContactHistory], stored: Double, loss: Double, contactPower: Double, reserved: Int,
                            policy: ToothContactPolicy, work: inout ToothContactWork) throws(ToothContactError) -> ToothPhysicalSample {
        let input: RigidDynamicsInput
        do { input=try RigidDynamicsInput(snapshot:snapshot,velocity:snapshot.coordinateRate,inertias:model.inertias,gravity:nil,bodyWrenches:loads) }
        catch { throw .dynamics(error) }
        let system=try assemble(input,policy:policy,reserved:reserved,work:&work)
        let solved=try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try self.dynamics.forward(system,driveForce:model.driveForce,policy:policy.dynamics,work:&local)
        }
        guard solved.acceleration.count == 2, solved.driveForce == model.driveForce else { throw .invalidSupplierOutput }
        var original=[Double](repeating:0,count:2)
        try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try RigidEquationKernel().originalInertialForce(system,acceleration:solved.acceleration,includeBias:true,into:&original,work:&local)
        }
        try work.charge(128)
        for i in 0..<2 {
            let known: Double
            do { known=try system.forces.total(at:i) } catch { throw .dynamics(error) }
            try ToothArithmetic.close(original[i],known+model.driveForce[i],scale:policy.dynamics.energyScale,policy:policy)
        }
        let energy=try ToothArithmetic.numeric(reserved:reserved,policy:policy,work:&work) { (local: inout NumericalWork) throws(DynamicsError) in
            try RigidEquationKernel().energy(system,acceleration:solved.acceleration,angularMomentumReference:.zero,requireComplete:true,work:&local)
        }
        guard let potential=energy.potentialEnergy else { throw .invalidSupplierOutput }
        try ToothArithmetic.close(potential,stored,scale:policy.dynamics.energyScale,policy:policy)
        let power=try ToothArithmetic.value(contactPower+model.driveForce[0]*input.velocity[0]+model.driveForce[1]*input.velocity[1])
        try ToothArithmetic.close(energy.kineticEnergyRate,power,scale:policy.dynamics.energyScale/policy.dynamics.timeScale,policy:policy)
        try ToothArithmetic.close(system.forces.actualPower,contactPower,scale:policy.dynamics.energyScale/policy.dynamics.timeScale,policy:policy)
        guard energy.time == snapshot.time, energy.frame == model.tree.worldFrame else { throw .invalidSupplierOutput }
        return ToothPhysicalSample(acceleration:solved.acceleration,contactForce:system.forces.contact,observations:observations,histories:histories,
            energy:energy,storedEnergy:stored,dissipationPower:loss)
    }
    @inline(never)
    internal func assemble(_ input: RigidDynamicsInput, policy: ToothContactPolicy, reserved: Int,
                          work: inout ToothContactWork) throws(ToothContactError) -> RigidDynamicsSystem {
        try ToothArithmetic.check(policy); try work.beginCall()
        let remaining=work.budget.arithmeticOperations-work.operations, storage=work.budget.scalarStorage-reserved
        let numericalBudget: NumericalBudget, loadBudget: LoadBudget
        do { numericalBudget=try NumericalBudget(scalarStorage:storage/2,arithmeticOperations:remaining/2,iterations:work.budget.iterations-work.iterations) }
        catch { throw .numerical(error) }
        do { loadBudget=try LoadBudget(maximumWork:remaining-remaining/2,maximumScalars:storage-storage/2,isCancelled:policy.isCancelled) }
        catch { throw .capacityExceeded }
        var numerical=NumericalWork(budget:numericalBudget), load=LoadWork(budget:loadBudget)
        do { try numerical.chargeOperations(1); try numerical.advanceIteration() } catch {
            try work.charge(numerical.operations,storage:reserved,iterations:numerical.iterations)
            throw .numerical(error)
        }
        do { try load.charge(1) } catch {
            try work.charge(ToothArithmetic.sum(numerical.operations,load.consumed),storage:reserved,iterations:numerical.iterations)
            throw .capacityExceeded
        }
        let result: Result<RigidDynamicsSystem,DynamicsError>
        do { result = .success(try RigidEquationKernel().assemble(input,admission:policy.admission,loadWork:&load,work:&numerical)) }
        catch { result = .failure(error) }
        guard numerical.budget == numericalBudget, numerical.operations >= 1, numerical.iterations >= 1,
              load.budget.maximumWork == loadBudget.maximumWork, load.budget.maximumScalars == loadBudget.maximumScalars,
              load.consumed >= 1 else {
            // Both local operation seeds and the numerical iteration preceded the callback.
            try work.charge(2,storage:reserved,iterations:1)
            throw .invalidSupplierLedger(failedSupplierWorkUnavailable:true)
        }
        try work.charge(ToothArithmetic.sum(numerical.operations,load.consumed),
            storage:ToothArithmetic.sum(reserved,ToothArithmetic.sum(numerical.peakScalarStorage,load.peakScalars)),iterations:numerical.iterations)
        try ToothArithmetic.check(policy)
        switch result { case .success(let system): return system; case .failure(let error): throw .dynamics(error) }
    }
}
