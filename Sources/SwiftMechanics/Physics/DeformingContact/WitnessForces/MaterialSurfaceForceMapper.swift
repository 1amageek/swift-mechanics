public struct MaterialSurfaceForceMapper: SurfaceContactForceMapping {
    private let laws: any ContactLawEvaluating
    public init(laws: any ContactLawEvaluating = CompliantContactEvaluator()) { self.laws=laws }
    @inline(never)
    public func initialHistory(_ witness: SurfaceContactWitness, key: String, pair: ContactLawPair, policy p: DeformingContactPolicy,
                               work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> ContactHistory {
        try admitLaw(pair)
        let identity=try identity(witness,key:key,policy:p,work:&work)
        let previous=lawWork
        var captured: ContactHistory?, failure: ContactLawError?
        do throws(ContactLawError) { captured=try laws.initialHistory(identity:identity,pair:pair,timeSeconds:witness.snapshot.timeSeconds,work:&lawWork) }
        catch { failure=error }
        try ledger(previous,&lawWork)
        if let failure { throw .law(failure,failedSupplierWorkUnavailable:true) }
        guard let result=captured else { throw .invalidSupplierOutput }
        guard result.identity == identity, result.pair == pair, result.timeSeconds == witness.snapshot.timeSeconds, result.sequence == 0 else { throw .invalidSupplierOutput }
        try SurfaceArithmetic.check(p)
        return result
    }
    @inline(never)
    public func evaluate(_ witness: SurfaceContactWitness, current: DeformingSurfaceSnapshot, currentObstacle: CollisionProxy?, key: String, pair: ContactLawPair, accepted: ContactHistory,
                         timeStep: Double, policy p: DeformingContactPolicy, lawPolicy: ContactAcceptancePolicy,
                         work: inout NumericalWork, lawWork: inout ContactWork) throws(DeformingContactError) -> SurfaceForceTrial {
        try SurfaceArithmetic.check(p); try admitLaw(pair)
        try SurfaceQueryAdmission.snapshot(current,policy:p,work:&work)
        try SurfaceQueryAdmission.snapshot(witness.snapshot,policy:p,work:&work)
        if let obstacle=currentObstacle { try SurfaceQueryAdmission.geometry(obstacle.geometry,policy:p,work:&work) }
        if let obstacle=witness.obstacle { try SurfaceQueryAdmission.geometry(obstacle.geometry,policy:p,work:&work) }
        guard current.surface === witness.snapshot.surface, currentObstacle == witness.obstacle, current.geometryRevision == witness.snapshot.geometryRevision,
              current.timeSeconds == witness.snapshot.timeSeconds, current.state.positions == witness.snapshot.state.positions,
              current.state.velocities == witness.snapshot.state.velocities else { throw .staleGeometry }
        guard current.state.positions.count <= p.maximumNodes else { throw .capacityExceeded }
        let identity=try identity(witness,key:key,policy:p,work:&work)
        guard accepted.identity == identity, accepted.pair == pair, accepted.timeSeconds == current.timeSeconds else { throw .staleHistory }
        let transport=try kinematics(witness,policy:p,work:&work)
        let input: ContactInput
        do { input=try ContactInput(identity:identity,basis:ContactBasis(frame:identity.frame,contactToQuery:witness.contactRotation),separation:witness.separation,
            relativeVelocity:transport.relative,relativeAngularVelocity:.zero,startTimeSeconds:current.timeSeconds,timeStepSeconds:timeStep) }
        catch { throw .law(error,failedSupplierWorkUnavailable:false) }
        let previous=lawWork
        var captured: ContactResponse?, failure: ContactLawError?
        do throws(ContactLawError) { captured=try laws.evaluate(input:input,pair:pair,accepted:accepted,policy:lawPolicy,work:&lawWork) }
        catch { failure=error }
        try ledger(previous,&lawWork)
        if let failure { throw .law(failure,failedSupplierWorkUnavailable:true) }
        guard let response=captured else { throw .invalidSupplierOutput }
        guard accepted.sequence < UInt64.max, response.trialHistory.identity == identity, response.trialHistory.pair == pair,
              response.acceptedHistorySequence == accepted.sequence, response.trialHistory.sequence == accepted.sequence+1,
              response.trialHistory.timeSeconds == current.timeSeconds+timeStep, response.coupleOnB == .zero else { throw .invalidSupplierOutput }
        return try map(response,witness:witness,transport:transport,policy:p,work:&work)
    }
    private func ledger(_ before: ContactWork, _ after: inout ContactWork) throws(DeformingContactError) {
        guard after.budget.operations == before.budget.operations, after.budget.scalarStorage == before.budget.scalarStorage,
              after.budget.records == before.budget.records, after.operations >= before.operations, after.peakScalarStorage >= before.peakScalarStorage else { after=before; throw .supplierLedgerReplaced }
    }
    private func admitLaw(_ pair: ContactLawPair) throws(DeformingContactError) {
        // FIXME(INCOMPLETE_IMPLEMENTATION): Angular resistance, cohesion and hard impact reach nodal surface ports.
        // Their couple transport/dynamics and independent original acceptance must be implemented before admission.
        guard pair.lossPolicy == .compliantDampingOnly, pair.parameters.cohesion == .none,
              pair.parameters.resistance.rollingCoefficient == 0, pair.parameters.resistance.spinningCoefficient == 0 else { throw .unsupportedDomain }
    }
    @inline(never)
    private func identity(_ witness: SurfaceContactWitness, key: String, policy p: DeformingContactPolicy,
                          work: inout NumericalWork) throws(DeformingContactError) -> ContactIdentity {
        try SurfaceQueryAdmission.snapshot(witness.snapshot,policy:p,work:&work)
        try SurfaceArithmetic.text(witness.secondBody.id.key,p,&work)
        try SurfaceArithmetic.text(key,p,&work)
        guard p.maximumIdentifierBytes >= 27, let first=witness.snapshot.surface.triangles.first(where: { $0.feature == witness.first.feature }),
              let vertex=witness.first.barycentric.firstIndex(of:1) else { throw .invalidInput }
        let node=witness.snapshot.surface.mesh.mesh.nodes[first.nodes[vertex]].identifier
        let secondKey: String, secondRevision: UInt64
        if let second=witness.second { secondKey="face:\(second.feature.cell):\(second.feature.oppositeNode)"; secondRevision=witness.snapshot.surface.mesh.mesh.revision }
        else if let obstacle=witness.obstacle {
            try SurfaceArithmetic.text(obstacle.geometry.colliderID.key,p,&work)
            guard obstacle.geometry.colliderID.key.utf8.count <= p.maximumIdentifierBytes-9 else { throw .capacityExceeded }
            secondKey="collider:\(obstacle.geometry.colliderID.key)"; secondRevision=obstacle.geometry.geometryRevision
        } else { throw .invalidInput }
        do { return try ContactIdentity(key:key,firstBody:witness.snapshot.surface.body,secondBody:witness.secondBody,
            frame:ModelReference(id:witness.snapshot.state.frame,revision:witness.snapshot.surface.mesh.mesh.revision),
            firstGeometryRevision:witness.snapshot.surface.mesh.mesh.revision,secondGeometryRevision:secondRevision,
            tangentLayoutRevision:witness.snapshot.surface.mesh.mesh.revision,
            firstMaterialSite:ContactMaterialSite(key:"node:\(node)",revision:witness.snapshot.surface.mesh.mesh.revision),
            secondMaterialSite:ContactMaterialSite(key:secondKey,revision:secondRevision)) } catch { throw .law(error,failedSupplierWorkUnavailable:false) }
    }
    @inline(never)
    private func kinematics(_ w: SurfaceContactWitness, policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfaceTransportKinematics {
        let updater: any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
        let a=try updater.point(w.first,in:w.snapshot,policy:p,work:&work)
        if let second=w.second {
            guard let face=w.snapshot.surface.triangles.first(where: { $0.feature == second.feature }) else { throw .staleGeometry }
            let frame=try SelectedSurfaceWitnessQueries.frame(face,snapshot:w.snapshot,policy:p)
            let b=try updater.point(second,in:w.snapshot,policy:p,work:&work)
            try SurfaceArithmetic.charge(256,p,&work)
            let velocities=w.snapshot.state.velocities
            let ud=try SurfaceArithmetic.core { () throws(CoreError) in try velocities[face.nodes[1]].subtracting(velocities[face.nodes[0]]) }
            let vd=try SurfaceArithmetic.core { () throws(CoreError) in try velocities[face.nodes[2]].subtracting(velocities[face.nodes[0]]) }
            let cd=try SurfaceArithmetic.core { () throws(CoreError) in try ud.cross(frame.secondEdge).adding(frame.firstEdge.cross(vd)) }
            let nd=try SurfaceArithmetic.core { () throws(CoreError) in try cd.subtracting(frame.normal.scaled(by:frame.normal.dot(cd))).scaled(by:1/frame.doubleArea) }
            let relative=try SurfaceArithmetic.core { () throws(CoreError) in try b.velocity.adding(nd.scaled(by:w.separation)).subtracting(a.velocity) }
            return SurfaceTransportKinematics(relative:relative,frame:frame)
        }
        return SurfaceTransportKinematics(relative:try SurfaceArithmetic.core { () throws(CoreError) in try a.velocity.scaled(by:-1) },frame:nil)
    }
    @inline(never)
    private func map(_ response: ContactResponse, witness w: SurfaceContactWitness, transport: SurfaceTransportKinematics,
                     policy p: DeformingContactPolicy, work: inout NumericalWork) throws(DeformingContactError) -> SurfaceForceTrial {
        let count=w.snapshot.state.positions.count
        let storage=try SurfaceArithmetic.numerical { () throws(NumericalError) in try NumericalWork.sum(384,NumericalWork.product(3,count)) }
        try SurfaceArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(storage) }
        try SurfaceArithmetic.charge(512,p,&work)
        var forces=[Vector3](repeating:.zero,count:count)
        guard let first=w.snapshot.surface.triangles.first(where: { $0.feature == w.first.feature }) else { throw .staleMesh }
        let f=response.forceOnB
        for i in 0..<3 { forces[first.nodes[i]]=try SurfaceArithmetic.core { () throws(CoreError) in try forces[first.nodes[i]].subtracting(f.scaled(by:w.first.barycentric[i])) } }
        var reaction=SpatialWrench(torque:.zero,force:.zero)
        if let second=w.second, let frame=transport.frame {
            guard let face=w.snapshot.surface.triangles.first(where: { $0.feature == second.feature }) else { throw .staleMesh }
            let t=try SurfaceArithmetic.core { () throws(CoreError) in try f.subtracting(frame.normal.scaled(by:frame.normal.dot(f))).scaled(by:w.separation/frame.doubleArea) }
            let one=try SurfaceArithmetic.core { () throws(CoreError) in try frame.secondEdge.cross(t) }, two=try SurfaceArithmetic.core { () throws(CoreError) in try t.cross(frame.firstEdge) }
            let correction=[try SurfaceArithmetic.core { () throws(CoreError) in try one.adding(two).scaled(by:-1) },one,two]
            for i in 0..<3 { forces[face.nodes[i]]=try SurfaceArithmetic.core { () throws(CoreError) in try forces[face.nodes[i]].adding(f.scaled(by:second.barycentric[i])).adding(correction[i]) } }
        } else { reaction=SpatialWrench(torque:try SurfaceArithmetic.core { () throws(CoreError) in try w.pointA.cross(f) },force:f) }
        var force=reaction.force, moment=reaction.torque, power=0.0
        for i in forces.indices {
            try SurfaceArithmetic.charge(128,p,&work)
            force=try SurfaceArithmetic.core { () throws(CoreError) in try force.adding(forces[i]) }
            moment=try SurfaceArithmetic.core { () throws(CoreError) in try moment.adding(w.snapshot.state.positions[i].cross(forces[i])) }
            power=try SurfaceArithmetic.finite(power+SurfaceArithmetic.core { () throws(CoreError) in try forces[i].dot(w.snapshot.state.velocities[i]) })
        }
        let fr=try SurfaceArithmetic.core { () throws(CoreError) in try force.magnitude() }, mr=try SurfaceArithmetic.core { () throws(CoreError) in try moment.magnitude() }
        let direct=try SurfaceArithmetic.core { () throws(CoreError) in try f.dot(transport.relative) }
        let pr=abs(power-direct)
        guard fr <= p.forceTolerance, mr <= p.momentTolerance, pr <= p.powerTolerance,
              abs(direct-response.relativeMechanicalPower) <= p.powerTolerance else { throw .physicalResidual }
        try SurfaceArithmetic.check(p)
        return SurfaceForceTrial(witness:w,response:response,forces:forces,reaction:reaction,relativeVelocity:transport.relative,
            mappedPower:power,forceResidual:fr,momentResidual:mr,powerResidual:pr)
    }
}
