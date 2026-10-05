internal enum ContactRangeArithmetic {
    static func core<T>(_ body: () throws(CoreError) -> T) throws(ContactRangeObservationError) -> T {
        do throws(CoreError) { return try body() } catch { throw .core(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(ContactRangeObservationError) -> T {
        do throws(NumericalError) { return try body() } catch { throw .numerical(error) }
    }
    static func check(_ policy: ContactRangeObservationPolicy) throws(ContactRangeObservationError) {
        guard !Task.isCancelled, !policy.observation.isCancelled() else { throw .cancelled }
    }
    static func charge(_ count: Int, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try numerical { () throws(NumericalError) in try work.chargeOperations(count) }
    }
    static func storage(_ count: Int, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try numerical { () throws(NumericalError) in try work.requireStorage(count) }
    }
    static func slots(_ count: Int, _ stride: Int, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try numerical { () throws(NumericalError) in try work.requireStorage(NumericalWork.product(count,stride)) }
    }
    static func metadata(_ texts: [String], _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        var bytes=0
        for text in texts {
            for _ in text.utf8 {
                guard bytes < policy.maximumMetadataBytes else { throw .capacityExceeded }
                bytes += 1;try charge(1,&work);try check(policy)
            }
        }
    }
    static func representations(_ values: BodyRepresentations, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        for value in [values.geometricShape,values.displayGeometry,values.collisionGeometry] {
            if let value { try metadata([value.assetKey,value.provenance.source],policy,&work) }
        }
    }
    static func recipe(_ value: ObservationColliderBinding, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try metadata([value.colliderID.key,value.body.key],policy,&work)
        try representations(value.representations,policy,&work);try charge(64,&work)
    }
    static func geometry(_ value: CollisionGeometryIdentity, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try metadata([value.colliderID.key,value.bodyID.key,value.frameID.key],policy,&work)
        try metadata([value.representation.assetKey,value.representation.provenance.source],policy,&work);try charge(64,&work)
    }
    static func model(_ model: CompiledMechanicalModel, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        let d=model.descriptor
        guard d.bodies.count <= policy.observation.maximumBodies,d.joints.count <= policy.observation.maximumBodies,
              d.initialState.q.count <= policy.observation.maximumCoordinates,d.initialState.v.count <= policy.observation.maximumCoordinates,
              d.initialState.acceleration.count <= policy.observation.maximumCoordinates else { throw .capacityExceeded }
        for count in [d.bodies.count,d.joints.count,d.representationRequirements.count,d.features.count,d.extensions.count,d.initialState.prescribedAnchors.count] { try slots(count,256,&work) }
        try metadata([d.identity,d.root.key,d.worldFrame.key],policy,&work)
        for body in d.bodies {
            try metadata([body.id.key,body.frame.key],policy,&work);try representations(body.representations,policy,&work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): Planar collider observation admission is not qualified.
            // This scene preparation path refuses it until original reduced source/frame fixtures pass.
            guard case .spatial(let record)=body else { throw .unsupportedRepresentation }
            if let inertia=record.inertia { try metadata([inertia.provenance.source],policy,&work) }
            try charge(256,&work)
        }
        for joint in d.joints {
            let r=joint.record
            try metadata([r.id.key,r.parentBody.key,r.childBody.key,r.parentAnchor.frame.key,r.childAnchor.frame.key],policy,&work)
            try slots(r.manifold.orderedAxes.count,16,&work);try charge(256,&work)
        }
        for requirement in d.representationRequirements {
            try metadata([requirement.body.key],policy,&work);try slots(requirement.geometry.count,1,&work);try charge(requirement.geometry.count,&work)
        }
        for feature in d.features { try metadata([feature.feature],policy,&work);try charge(8,&work) }
        for ext in d.extensions {
            try slots(ext.references.count,8,&work);try slots(ext.parameters.count,16,&work)
            try metadata([ext.id.key,ext.schema],policy,&work)
            for ref in ext.references { try metadata([ref.key],policy,&work) }
            for parameter in ext.parameters { try metadata([parameter.name],policy,&work);try charge(16,&work) }
        }
        for anchor in d.initialState.prescribedAnchors { try metadata([anchor.frame.key],policy,&work);try charge(64,&work) }
        try charge(d.initialState.q.count+d.initialState.v.count+d.initialState.acceleration.count,&work)
        try check(policy)
    }
    static func scene(_ scene: ContactRangeScene, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        try check(policy)
        guard scene.colliders.count <= policy.maximumColliders,scene.collision.proxies.count == scene.colliders.count else { throw .capacityExceeded }
        try slots(scene.colliders.count,256,&work)
        try model(scene.source.model,policy,&work)
        for value in scene.colliders { try recipe(value,policy,&work) }
    }
    static func history(_ value: ContactHistory, _ policy: ContactRangeObservationPolicy, _ work: inout NumericalWork) throws(ContactRangeObservationError) {
        let id=value.identity
        // FIXME(INCOMPLETE_IMPLEMENTATION): Deforming material-site tactile sensing is not supported
        // by this rigid point-rate observer; it must not issue success until nodal source evidence exists.
        guard id.firstMaterialSite == nil,id.secondMaterialSite == nil else { throw .unsupportedRepresentation }
        try metadata([id.key,id.firstBody.id.key,id.secondBody.id.key,id.frame.id.key],policy,&work)
        try metadata([value.pair.firstMaterial.id.key,value.pair.secondMaterial.id.key],policy,&work);try charge(256,&work)
    }
    static func pose(_ a: RigidTransform, _ b: RigidTransform) throws(ContactRangeObservationError) -> Bool {
        guard a.translation == b.translation else { return false }
        return try core { () throws(CoreError) in try a.rotation.matrix() == b.rotation.matrix() }
    }
    static func mount(_ a: ObservationMount, _ b: ObservationMount) throws(ContactRangeObservationError) -> Bool {
        guard a.sensor == b.sensor,a.body == b.body,a.sensorFrame == b.sensorFrame else { return false }
        return try pose(a.sensorToBody,b.sensorToBody)
    }
    /// Irreversible admission is charged before retaining the known callback prefix.
    static func collision<T>(_ work: inout CollisionWork, _ body: (inout CollisionWork) throws(CollisionError) -> T) throws(ContactRangeObservationError) -> T {
        do throws(CollisionError) { try work.charge(1) } catch { throw .collision(error) }
        let before=work
        var result:T?,failure:CollisionError?
        do throws(CollisionError) { result=try body(&work) } catch { failure=error }
        guard work.budget == before.budget,work.operations >= before.operations,work.iterations >= before.iterations,
              work.peakScalarStorage >= before.peakScalarStorage else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw .collisionSupplier(failure) }
        guard let result else { throw .invalidSupplierEvidence };return result
    }
    static func current<T>(_ work: inout ContactWork, _ body: (inout ContactWork) throws(ContactCurrentError) -> T) throws(ContactRangeObservationError) -> T {
        do throws(ContactLawError) { try work.consume(operations:1,scalarStorage:0,records:0) } catch { throw .current(.law(error)) }
        let before=work
        var result:T?,failure:ContactCurrentError?
        do throws(ContactCurrentError) { result=try body(&work) } catch { failure=error }
        guard work.budget.operations == before.budget.operations,work.budget.scalarStorage == before.budget.scalarStorage,
              work.budget.records == before.budget.records,work.operations >= before.operations,
              work.peakScalarStorage >= before.peakScalarStorage else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw .currentSupplier(failure) }
        guard let result else { throw .invalidSupplierEvidence };return result
    }
    @inline(never)
    static func mounted(_ service: any KinematicObserving, scene: ContactRangeScene, mount: ObservationMount,
                        policy: ContactRangeObservationPolicy, work: inout NumericalWork) throws(ContactRangeObservationError) -> MountedMotionObservation {
        try metadata([mount.sensor.key,mount.body.key,mount.sensorFrame.key],policy,&work);try charge(1,&work)
        let before=work
        var result:MountedMotionObservation?,failure:ObservationError?
        do throws(ObservationError) { result=try service.motion(source:scene.source,mount:mount,policy:policy.observation,work:&work) } catch { failure=error }
        guard work.budget == before.budget,work.operations >= before.operations,work.iterations >= before.iterations,
              work.peakScalarStorage >= before.peakScalarStorage else { work=before;throw .supplierLedgerReplaced }
        if let failure { throw .observationSupplier(failure) }
        guard let supplied=result else { throw .invalidSupplierEvidence }
        try check(policy)
        let original:MountedMotionObservation
        do throws(ObservationError) { original=try ReferenceKinematicObserver().motion(source:scene.source,mount:mount,policy:policy.observation,work:&work) } catch { throw .observation(error) }
        try metadata([supplied.header.model.identity,supplied.header.sensor.key,supplied.header.body.key,supplied.header.expressedFrame.key],policy,&work)
        try storage(96,&work);try charge(96,&work)
        guard supplied.header.model == original.header.model,supplied.header.timeSeconds == original.header.timeSeconds,
              supplied.header.sensor == original.header.sensor,supplied.header.body == original.header.body,
              supplied.header.expressedFrame == original.header.expressedFrame,
              supplied.header.accelerationAuthority == original.header.accelerationAuthority,
              supplied.header.temporalMeaning == original.header.temporalMeaning,
              supplied.velocity == original.velocity,supplied.acceleration == original.acceleration else { throw .invalidSupplierEvidence }
        guard try pose(supplied.sensorToWorld,original.sensorToWorld) else { throw .invalidSupplierEvidence }
        try check(policy);return original
    }
}
