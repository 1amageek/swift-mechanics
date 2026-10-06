public struct CompoundCollisionIdentity: Equatable, Sendable {
    public let colliderID: EntityID
    public let bodyID: EntityID
    public let localFrameID: EntityID
    public let localFrameRevision: UInt64
    public let revision: UInt64
    public let provenance: SourceProvenance

    public init(colliderID: EntityID, bodyID: EntityID, localFrameID: EntityID,
                localFrameRevision: UInt64, revision: UInt64, provenance: SourceProvenance) throws(CompoundCollisionError) {
        guard colliderID.kind == .collider, bodyID.kind == .body, localFrameID.kind == .frame else { throw .invalidIdentity }
        self.colliderID = colliderID; self.bodyID = bodyID; self.localFrameID = localFrameID
        self.localFrameRevision = localFrameRevision; self.revision = revision; self.provenance = provenance
    }
}
