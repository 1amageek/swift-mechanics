public struct HeightfieldReference: Equatable, Sendable {
    public let colliderID: EntityID
    public let frameID: EntityID
    public let frameRevision: UInt64
    public let geometryRevision: UInt64
    public let source: SourceProvenance

    public init(colliderID: EntityID, frameID: EntityID, frameRevision: UInt64,
                geometryRevision: UInt64, source: SourceProvenance) throws(HeightfieldError) {
        guard colliderID.kind == .collider, frameID.kind == .frame else { throw .invalidIdentity }
        self.colliderID = colliderID; self.frameID = frameID
        self.frameRevision = frameRevision; self.geometryRevision = geometryRevision
        self.source = source
    }
}
