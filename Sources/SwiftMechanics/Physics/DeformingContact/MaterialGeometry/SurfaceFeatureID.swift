public struct SurfaceFeatureID: Hashable, Sendable {
    public let cell: UInt64
    public let oppositeNode: Int
    public init(cell: UInt64, oppositeNode: Int) throws(DeformingContactError) {
        guard (0..<4).contains(oppositeNode) else { throw .invalidInput }; self.cell=cell; self.oppositeNode=oppositeNode
    }
}
