public struct CollisionPairIdentity: Equatable, Sendable {
    public let first: CollisionGeometryIdentity
    public let second: CollisionGeometryIdentity

    public init(first: CollisionGeometryIdentity, second: CollisionGeometryIdentity) throws(CollisionError) {
        guard first.colliderID != second.colliderID else { throw .invalidIdentity }
        guard first.frameID == second.frameID, first.frameRevision == second.frameRevision else { throw .frameMismatch }
        self.first = first; self.second = second
    }

    public func key() throws(CollisionError) -> CollisionPairKey {
        try CollisionPairKey(first.colliderID, second.colliderID)
    }
}
