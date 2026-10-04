
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public struct RigidHardImpactAdapter: ImpactPortAdapting {
    private let equations: any RigidEquationComputing
    public init(equations: any RigidEquationComputing = RigidEquationKernel()) { self.equations=equations }
    @inline(never)
    public func prepare(_ input: HardImpactInput, policy: HybridPolicy, admission: DynamicsAdmission,
                        loadWork: inout LoadWork, work: inout NumericalWork, cancellation: HybridCancellation) throws(HybridError) -> PreparedImpact {
        try cancellation.check()
        let request=HardImpactRequest(input:input,policy:policy,admission:admission)
        let assembly=try assembleSystem(admitSnapshot(request),loadWork:&loadWork,work:&work)
        return completedImpact(assembly,rows:try prepareRows(assembly,work:&work,cancellation:cancellation))
    }
    @inline(never)
    private func admitSnapshot(_ request: HardImpactRequest) throws(HybridError) -> HardImpactSnapshot {
        let input=request.input, policy=request.policy
        let n=input.model.tree.layout.velocityCount
        guard !input.contacts.isEmpty, input.contacts.count <= policy.maximumContacts,
              input.collision.proxies.count <= policy.maximumColliders, input.model.tree.bodies.count <= policy.maximumBodies,
              input.inertias.count <= policy.maximumBodies, n <= policy.maximumVelocities, n == policy.impulseScales.count else { throw .capacityExceeded }
        guard input.model.stamp == input.physical.stamp else { throw .staleModel }
        guard input.expectedCollisionRevision == input.collision.revision else { throw .staleGeometry }
        for body in input.model.tree.bodies {
            guard body.id.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
        }
        let snapshot: KinematicSnapshot
        do { snapshot=try input.model.evaluate(input.physical) } catch { throw .compiler(error) }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Moving-anchor hard impacts reach this admission path.
        // Prescribed boundary momentum/energy transfer must be implemented and independently verified before admission.
        guard snapshot.bodies.allSatisfy({ $0.prescribedDriftVelocity == SpatialMotion(angular:.zero,linear:.zero) }) else { throw .unsupportedDomain }
        return HardImpactSnapshot(request:request,snapshot:snapshot)
    }
    @inline(never)
    private func assembleSystem(_ source: HardImpactSnapshot, loadWork: inout LoadWork,
                                work: inout NumericalWork) throws(HybridError) -> HardImpactAssembly {
        let input=source.request.input, n=input.model.tree.layout.velocityCount
        let dynamicsInput: RigidDynamicsInput
        do { dynamicsInput=try RigidDynamicsInput(snapshot:source.snapshot,velocity:input.physical.state.v,inertias:input.inertias,gravity:nil) }
        catch { throw .dynamics(error) }
        let system: RigidDynamicsSystem
        do { system=try equations.assemble(dynamicsInput,admission:source.request.admission,loadWork:&loadWork,work:&work) }
        catch { throw .dynamics(error) }
        let count=try ImpactArithmetic.numerical { () throws(NumericalError) in try NumericalWork.product(n,input.contacts.count) }
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.requireStorage(try NumericalWork.sum(system.scalarStorage,count)) }
        return HardImpactAssembly(source:source,system:system,contacts:input.contacts.sorted { $0.eventID < $1.eventID },rowCount:count,velocityCount:n)
    }
    @inline(never)
    private func prepareRows(_ assembly: HardImpactAssembly, work: inout NumericalWork,
                             cancellation: HybridCancellation) throws(HybridError) -> [Double] {
        var rows=[Double](repeating:0,count:assembly.rowCount)
        for index in assembly.contacts.indices {
            try cancellation.check()
            if index > 0, assembly.contacts[index-1].eventID == assembly.contacts[index].eventID { throw .invalidInput }
            try prepareRow(assembly,index:index,into:&rows,offset:index*assembly.velocityCount,work:&work)
        }
        return rows
    }
    @inline(never)
    private func completedImpact(_ assembly: HardImpactAssembly, rows: [Double]) -> PreparedImpact {
        PreparedImpact(input:assembly.source.request.input,system:assembly.system,rows:rows)
    }
    @inline(never)
    private func prepareRow(_ assembly: HardImpactAssembly, index: Int, into rows: inout [Double],
                            offset: Int, work: inout NumericalWork) throws(HybridError) {
        let geometry=try rowGeometry(assembly,index:index)
        try validateMetadata(geometry)
        try validateWitness(geometry)
        let bodies=try rowBodies(geometry)
        try validateBodyPoses(bodies)
        try validateLaw(geometry)
        try fillRow(pointColumns(bodies,work:&work),into:&rows,offset:offset)
    }
    @inline(never)
    private func rowGeometry(_ assembly: HardImpactAssembly, index: Int) throws(HybridError) -> HardImpactRowGeometry {
        let contact=assembly.contacts[index], proxies=assembly.source.request.input.collision.proxies
        guard proxies.indices.contains(contact.firstProxyIndex), proxies.indices.contains(contact.secondProxyIndex),
              contact.firstProxyIndex != contact.secondProxyIndex else { throw .invalidInput }
        return HardImpactRowGeometry(assembly:assembly,contact:contact,first:proxies[contact.firstProxyIndex],second:proxies[contact.secondProxyIndex])
    }
    @inline(never)
    private func validateMetadata(_ geometry: HardImpactRowGeometry) throws(HybridError) {
        let snapshot=geometry.assembly.source.snapshot, policy=geometry.assembly.source.request.policy
        for proxy in [geometry.first,geometry.second] {
            for id in [proxy.geometry.bodyID,proxy.geometry.colliderID,proxy.geometry.frameID] {
                guard id.key.utf8.count <= policy.maximumIdentifierBytes else { throw .capacityExceeded }
            }
            guard proxy.geometry.frameID == snapshot.tree.worldFrame, proxy.geometry.frameRevision == snapshot.tree.revision else { throw .staleModel }
        }
    }
    @inline(never)
    private func validateWitness(_ geometry: HardImpactRowGeometry) throws(HybridError) {
        let a=geometry.first, b=geometry.second, witness=geometry.contact.witness
        let policy=geometry.assembly.source.request.policy
        guard witness.pair.first == a.geometry, witness.pair.second == b.geometry else { throw .staleGeometry }
        guard a.filter.enabled, b.filter.enabled, !a.filter.isTrigger, !b.filter.isTrigger,
              a.filter.layerBits & b.filter.maskBits != 0, b.filter.layerBits & a.filter.maskBits != 0 else { throw .invalidWitness }
        guard witness.degeneracy == .regular, witness.approximationError == 0,
              a.geometry.resolution == .analytic, b.geometry.resolution == .analytic,
              abs(witness.separation) <= policy.lengthTolerance else { throw .invalidWitness }
        let norm=try ImpactArithmetic.core { () throws(CoreError) in try witness.normal.magnitude() }
        let balance=try ImpactArithmetic.core { () throws(CoreError) in try witness.pointB.subtracting(witness.pointA).subtracting(witness.normal.scaled(by:witness.separation)).magnitude() }
        guard abs(norm-1) <= policy.normalTolerance, balance <= policy.lengthTolerance,
              try ImpactArithmetic.samePose(witness.poseA,a.pose,policy:policy), try ImpactArithmetic.samePose(witness.poseB,b.pose,policy:policy) else { throw .invalidWitness }
    }
    @inline(never)
    private func rowBodies(_ geometry: HardImpactRowGeometry) throws(HybridError) -> HardImpactRowBodies {
        let snapshot=geometry.assembly.source.snapshot
        guard let first=snapshot.bodies.first(where: { $0.body == geometry.first.geometry.bodyID }),
              let second=snapshot.bodies.first(where: { $0.body == geometry.second.geometry.bodyID }) else { throw .staleModel }
        return HardImpactRowBodies(geometry:geometry,first:first,second:second)
    }
    @inline(never)
    private func validateBodyPoses(_ bodies: HardImpactRowBodies) throws(HybridError) {
        let contact=bodies.geometry.contact, policy=bodies.geometry.assembly.source.request.policy
        guard try ImpactArithmetic.samePose(ImpactArithmetic.core { () throws(CoreError) in try bodies.first.motion.pose.composed(with:contact.firstColliderToBody) },bodies.geometry.first.pose,policy:policy),
              try ImpactArithmetic.samePose(ImpactArithmetic.core { () throws(CoreError) in try bodies.second.motion.pose.composed(with:contact.secondColliderToBody) },bodies.geometry.second.pose,policy:policy) else { throw .stalePose }
    }
    @inline(never)
    private func validateLaw(_ geometry: HardImpactRowGeometry) throws(HybridError) {
        let contact=geometry.contact
        // FIXME(INCOMPLETE_IMPLEMENTATION): Frictional/cohesive/resistive impact selections reach the hard normal port.
        // Coupled impulse equations and original law acceptance are required before admitting those selections.
        guard case .separateImpact=contact.law.lossPolicy, contact.law.parameters.friction == .none,
              contact.law.parameters.cohesion == .none, contact.law.parameters.resistance.rollingCoefficient == 0,
              contact.law.parameters.resistance.spinningCoefficient == 0 else { throw .unsupportedDomain }
    }
    @inline(never)
    private func pointColumns(_ bodies: HardImpactRowBodies, work: inout NumericalWork) throws(HybridError) -> HardImpactPointColumns {
        let witness=bodies.geometry.contact.witness, snapshot=bodies.geometry.assembly.source.snapshot
        let ra=try ImpactArithmetic.core { () throws(CoreError) in try witness.pointA.subtracting(bodies.first.motion.pose.translation) }
        let rb=try ImpactArithmetic.core { () throws(CoreError) in try witness.pointB.subtracting(bodies.second.motion.pose.translation) }
        let ja: ArraySlice<SpatialMotion>, jb: ArraySlice<SpatialMotion>
        do { ja=try snapshot.geometricColumns(body:bodies.first.body); jb=try snapshot.geometricColumns(body:bodies.second.body) } catch { throw .joints(error) }
        guard ja.count == bodies.geometry.assembly.source.request.input.physical.state.v.count, jb.count == ja.count else { throw .invalidInput }
        try ImpactArithmetic.numerical { () throws(NumericalError) in try work.chargeOperations(try NumericalWork.sum(256,try NumericalWork.product(64,ja.count))) }
        return HardImpactPointColumns(normal:witness.normal,firstOffset:ra,secondOffset:rb,first:ja,second:jb)
    }
    @inline(never)
    private func fillRow(_ columns: HardImpactPointColumns, into rows: inout [Double], offset: Int) throws(HybridError) {
        for i in 0..<columns.first.count {
            let pa=try ImpactArithmetic.point(columns.first[columns.first.startIndex+i],offset:columns.firstOffset), pb=try ImpactArithmetic.point(columns.second[columns.second.startIndex+i],offset:columns.secondOffset)
            rows[offset+i]=try ImpactArithmetic.core { () throws(CoreError) in try columns.normal.dot(pb.subtracting(pa)) }
        }
    }
}
