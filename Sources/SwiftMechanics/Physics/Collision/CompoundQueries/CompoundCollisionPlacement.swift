/// Current rigid placement; the assembly filter gates child queries without replacing child filters.
public struct CompoundCollisionPlacement: Sendable {
    public let compound: CompoundCollisionShape
    public let frameID: EntityID
    public let frameRevision: UInt64
    public let pose: RigidTransform
    public let filter: ColliderFilter

    public init(compound: CompoundCollisionShape, expectedRevision: UInt64, frameID: EntityID,
                frameRevision: UInt64, pose: RigidTransform, filter: ColliderFilter,
                policy: CompoundCollisionPolicy, work: inout CollisionWork) throws(CompoundCollisionError) {
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(16) }
        guard compound.children.count <= policy.maximumChildren else { throw .invalidChildren }
        guard compound.metadataBytes <= policy.maximumMetadataBytes else { throw .metadataLimit(limit: policy.maximumMetadataBytes) }
        var metadata = compound.metadataBytes
        try CompoundCollisionAccounting.text(frameID.key, bytes: &metadata, policy: policy, work: &work)
        guard compound.identity.revision == expectedRevision else {
            throw .staleRevision(expected: expectedRevision, actual: compound.identity.revision)
        }
        guard frameID.kind == .frame else { throw .invalidIdentity }
        self.compound = compound; self.frameID = frameID; self.frameRevision = frameRevision
        self.pose = pose; self.filter = filter
    }
}
