public struct ReferenceGranularEvolution: GranularEvolving, Sendable {
    private let geometry: any CollisionGeometryQuerying
    private let law: any ContactLawEvaluating
    public init(geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries(), law: any ContactLawEvaluating = CompliantContactEvaluator()) {
        self.geometry=geometry; self.law=law
    }
    @inline(never)
    public func step(accepted: GranularState, timeStepSeconds h: Double, gravity: Vector3, policy: GranularPolicy,
        workspace: inout GranularWorkspace, numericalWork: inout NumericalWork, collisionWork: inout CollisionWork,
        contactWork: inout ContactWork, supplierWork: inout GranularSupplierWork) throws(GranularError) -> GranularStepResult {
        try GranularArithmetic.check(policy)
        guard h.isFinite, h > 0 else { throw .invalidInput }
        let time=try GranularArithmetic.finite(accepted.timeSeconds+h)
        let (step,overflow)=accepted.steps.addingReportingOverflow(1)
        guard !overflow, time > accepted.timeSeconds else { throw .arithmeticFailure }
        try boundaryMotionAdmission(accepted,h:h,policy:policy,work:&numericalWork)
        try initialize(accepted,gravity:gravity,policy:policy,workspace:&workspace,work:&numericalWork)
        do { try numericalWork.advanceIteration() } catch { throw .numerical(error) }
        for i in accepted.model.bindings.indices {
            try evaluate(i,accepted:accepted,h:h,policy:policy,workspace:&workspace,work:&numericalWork,
                collisionWork:&collisionWork,contactWork:&contactWork,supplierWork:&supplierWork)
        }
        try GranularUpdate.advance(accepted:accepted,h:h,policy:policy,workspace:&workspace,work:&numericalWork)
        let evidence=try GranularUpdate.evidence(accepted:accepted,h:h,gravity:gravity,policy:policy,workspace:&workspace,work:&numericalWork)
        try GranularArithmetic.check(policy)
        // Immutable publication uses bounded COW owners; future workspace mutation may copy retained storage.
        let state=GranularState(model:accepted.model,motions:workspace.motions,contacts:workspace.contacts,random:accepted.random,timeSeconds:time,steps:step)
        return GranularStepResult(state:state,neighbors:workspace.neighbors,contacts:workspace.observations,boundaryReactions:workspace.reactions,evidence:evidence)
    }
    private func boundaryMotionAdmission(_ accepted: GranularState,h: Double,policy: GranularPolicy,work: inout NumericalWork) throws(GranularError) {
        for boundary in accepted.model.boundaries {
            try GranularArithmetic.charge(256,policy:policy,work:&work)
            let n=try GranularArithmetic.core { () throws(CoreError) in try boundary.proxy.pose.rotation.rotating(.unitZ) }
            let displacement=try GranularArithmetic.finite(h*abs(GranularArithmetic.dot(n,boundary.velocityAtOrigin)))
            let tilt=try GranularArithmetic.finite(h*GranularArithmetic.norm(GranularArithmetic.cross(n,boundary.angularVelocity)))
            // FIXME(INCOMPLETE_IMPLEMENTATION): Normal translation/tilt beyond caller frozen-geometry tolerances
            // requires time-evolved plane geometry and must not succeed in this invariant-half-space update.
            guard displacement <= policy.collision.lengthTolerance, tilt <= policy.collision.normalTolerance else { throw .unsupportedDomain }
        }
    }
    @inline(never)
    private func initialize(_ accepted: GranularState,gravity: Vector3,policy: GranularPolicy,workspace: inout GranularWorkspace,work: inout NumericalWork) throws(GranularError) {
        let n=accepted.model.particles.count, m=accepted.model.boundaries.count, c=accepted.model.bindings.count
        try GranularAdmission.capacity(n,m,policy:policy)
        guard c <= policy.maximumContacts else { throw .capacity(resource:"contacts",limit:policy.maximumContacts) }
        let slots=try GranularArithmetic.addCount(GranularArithmetic.product(n,40),GranularArithmetic.addCount(GranularArithmetic.product(c,300),GranularArithmetic.product(m,14)))
        try GranularArithmetic.storage(GranularArithmetic.addCount(slots,workspace.retainedSlots),work:&work)
        workspace.forces.removeAll(keepingCapacity:true); workspace.torques.removeAll(keepingCapacity:true)
        workspace.motions.removeAll(keepingCapacity:true); workspace.contacts.removeAll(keepingCapacity:true)
        workspace.observations.removeAll(keepingCapacity:true); workspace.neighbors.removeAll(keepingCapacity:true); workspace.reactions.removeAll(keepingCapacity:true)
        workspace.forces.reserveCapacity(n); workspace.torques.reserveCapacity(n); workspace.motions.reserveCapacity(n)
        workspace.contacts.reserveCapacity(c); workspace.observations.reserveCapacity(c); workspace.neighbors.reserveCapacity(min(c,policy.maximumNeighbors)); workspace.reactions.reserveCapacity(m)
        for particle in accepted.model.particles {
            try GranularArithmetic.charge(32,policy:policy,work:&work)
            workspace.forces.append(try GranularArithmetic.scale(gravity,particle.mass)); workspace.torques.append(.zero)
        }
        for boundary in accepted.model.boundaries {
            try GranularArithmetic.charge(32,policy:policy,work:&work)
            workspace.reactions.append(GranularBoundaryReaction(body:boundary.body,frame:accepted.model.frame,referencePoint:boundary.proxy.pose.translation,force:.zero,torque:.zero,prescribedPower:0))
        }
    }
    @inline(never)
    private func evaluate(_ index: Int,accepted: GranularState,h: Double,policy: GranularPolicy,workspace: inout GranularWorkspace,
        work: inout NumericalWork,collisionWork: inout CollisionWork,contactWork: inout ContactWork,supplierWork: inout GranularSupplierWork) throws(GranularError) {
        try GranularArithmetic.charge(2048,policy:policy,work:&work)
        let binding=accepted.model.bindings[index], first=binding.firstParticle
        let a=accepted.model.particles[first].proxy.moved(to:RigidTransform(rotation:.identity,translation:accepted.motions[first].position))
        let b: CollisionProxy
        if let second=binding.secondParticle {
            b=accepted.model.particles[second].proxy.moved(to:RigidTransform(rotation:.identity,translation:accepted.motions[second].position))
        } else if let boundary=binding.boundary { b=accepted.model.boundaries[boundary].proxy }
        else { throw .invalidBinding }
        try GranularArithmetic.proxy(a,policy:policy,work:&work); try GranularArithmetic.proxy(b,policy:policy,work:&work)
        try supplierWork.begin()
        let witness: CollisionWitness
        witness=try GranularSupplierGate.collision(work:&collisionWork) { (ledger: inout CollisionWork) throws(CollisionError) in
            try geometry.witness(first:a,second:b,policy:policy.collision,work:&ledger)
        }
        try GranularSupplierValidation.witness(witness,first:a,second:b,policy:policy,work:&work)
        guard witness.degeneracy == .regular else { throw .unsupportedDomain }
        let range: Double
        switch binding.law.parameters.cohesion { case .none: range=0; case .reversibleLinear(_,let r): range=r }
        if witness.separation <= range {
            guard workspace.neighbors.count < policy.maximumNeighbors else { throw .capacity(resource:"neighbors",limit:policy.maximumNeighbors) }
            workspace.neighbors.append(GranularNeighbor(bindingIndex:index,separation:witness.separation))
        }
        let point=try GranularArithmetic.scale(GranularArithmetic.add(witness.pointA,witness.pointB),0.5)
        let basis=try GranularContactTransport.basis(normal:witness.normal,previous:accepted.contacts[index].basis,frame:accepted.model.frame,policy:policy)
        guard try GranularArithmetic.norm(GranularArithmetic.sub(basis.normal,witness.normal)) <= policy.collision.normalTolerance else { throw .invalidSupplierOutput }
        let va=try GranularUpdate.pointVelocity(accepted.motions[first],at:point)
        let vb: Vector3, wb: Vector3
        if let second=binding.secondParticle {
            vb=try GranularUpdate.pointVelocity(accepted.motions[second],at:point); wb=accepted.motions[second].angularVelocity
        } else if let j=binding.boundary {
            let boundary=accepted.model.boundaries[j]
            vb=try GranularArithmetic.add(boundary.velocityAtOrigin,GranularArithmetic.cross(boundary.angularVelocity,GranularArithmetic.sub(point,boundary.proxy.pose.translation)))
            wb=boundary.angularVelocity
        } else { throw .invalidBinding }
        let relative=try GranularArithmetic.sub(vb,va), angularRelative=try GranularArithmetic.sub(wb,accepted.motions[first].angularVelocity)
        let input: ContactInput
        do { input=try ContactInput(identity:binding.identity,basis:basis,separation:witness.separation,
            relativeVelocity:relative,relativeAngularVelocity:angularRelative,
            startTimeSeconds:accepted.timeSeconds,timeStepSeconds:h) } catch { throw .contact(error,failedSupplierWorkUnavailable:false) }
        try supplierWork.begin()
        let response: ContactResponse
        response=try GranularSupplierGate.contact(work:&contactWork) { (ledger: inout ContactWork) throws(ContactLawError) in
            try law.evaluate(input:input,pair:binding.law,accepted:accepted.contacts[index].history,policy:policy.contact,work:&ledger)
        }
        try GranularSupplierValidation.response(response,input:input,binding:binding,accepted:accepted.contacts[index].history,h:h,policy:policy,work:&work)
        let force=response.forceOnB, couple=response.coupleOnB
        try accumulate(first,force:GranularArithmetic.scale(force,-1),couple:GranularArithmetic.scale(couple,-1),point:point,accepted:accepted,workspace:&workspace)
        if let second=binding.secondParticle { try accumulate(second,force:force,couple:couple,point:point,accepted:accepted,workspace:&workspace) }
        else if let j=binding.boundary {
            let old=workspace.reactions[j], boundary=accepted.model.boundaries[j]
            let torque=try GranularArithmetic.add(GranularArithmetic.cross(GranularArithmetic.sub(point,old.referencePoint),force),couple)
            let totalForce=try GranularArithmetic.add(old.force,force), totalTorque=try GranularArithmetic.add(old.torque,torque)
            let power=try GranularArithmetic.finite(GranularArithmetic.dot(totalForce,boundary.velocityAtOrigin)+GranularArithmetic.dot(totalTorque,boundary.angularVelocity))
            workspace.reactions[j]=GranularBoundaryReaction(body:old.body,frame:old.frame,referencePoint:old.referencePoint,force:totalForce,torque:totalTorque,prescribedPower:power)
        }
        workspace.contacts.append(GranularContactState(history:response.trialHistory,basis:basis))
        workspace.observations.append(GranularContactObservation(bindingIndex:index,separation:witness.separation,point:point,response:response))
    }
    private func accumulate(_ i: Int,force: Vector3,couple: Vector3,point: Vector3,accepted: GranularState,workspace: inout GranularWorkspace) throws(GranularError) {
        workspace.forces[i]=try GranularArithmetic.add(workspace.forces[i],force)
        let torque=try GranularArithmetic.add(GranularArithmetic.cross(GranularArithmetic.sub(point,accepted.motions[i].position),force),couple)
        workspace.torques[i]=try GranularArithmetic.add(workspace.torques[i],torque)
    }
}
