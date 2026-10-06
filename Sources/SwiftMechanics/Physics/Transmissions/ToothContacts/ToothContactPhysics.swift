internal final class ToothContactPhysics: Sendable {
    let model: ToothContactModel
    let geometry: any CollisionGeometryQuerying
    let laws: any ContactLawEvaluating
    let dynamics: any RigidDynamicsSolving
    let rigid: ToothRigidAcceptance
    init(model: ToothContactModel, geometry: any CollisionGeometryQuerying, laws: any ContactLawEvaluating,
         dynamics: any RigidDynamicsSolving) { self.model=model; self.geometry=geometry; self.laws=laws; self.dynamics=dynamics; rigid=ToothRigidAcceptance(model:model,dynamics:dynamics) }
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
        let pair=model.contacts[index]
        guard history.identity == (try identity(pair)), history.pair == pair.law, history.timeSeconds == start else { throw .staleSource }
        let kinematics=try ToothPairKinematics.evaluate(shared:self,pair:pair,snapshot:snapshot,policy:policy,work:&work)
        let first=kinematics.first, second=kinematics.second, witness=kinematics.witness
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
        let reserved=try ToothArithmetic.slots(teeth:model.teeth.count,contacts:model.contacts.count)
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
        let result=try rigid.evaluate(snapshot:snapshot,loads:loads,stored:stored,loss:loss,contactPower:contactPower,
            reserved:reserved,policy:policy,work:&work)
        return ToothPhysicalSample(acceleration:result.acceleration,contactForce:result.contactForce,observations:observations,histories:histories,
            energy:result.energy,storedEnergy:stored,dissipationPower:loss)
    }
    @inline(never)
    internal func assemble(_ input: RigidDynamicsInput, policy: ToothContactPolicy, reserved: Int,
                          work: inout ToothContactWork) throws(ToothContactError) -> RigidDynamicsSystem {
        try rigid.assemble(input,policy:policy,reserved:reserved,work:&work)
    }
}
