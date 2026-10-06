public struct ConvexPairIdentity: Equatable, Sendable {
    public let first: ConvexGeometryIdentity
    public let second: ConvexGeometryIdentity

    public init(first: ConvexGeometryIdentity, second: ConvexGeometryIdentity) throws(ConvexCollisionError) {
        guard first.colliderID != second.colliderID else { throw .collision(.invalidIdentity) }
        guard first.frameID == second.frameID, first.frameRevision == second.frameRevision else {
            throw .collision(.frameMismatch)
        }
        self.first = first; self.second = second
    }
}
