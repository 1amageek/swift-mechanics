public struct RefinementFace: Sendable {
    public let cell: UInt64, cellIndex: Int, oppositeNode: Int
    /// Outward oriented node indexes in the corresponding mesh, never a sorted orientation surrogate.
    public let nodes: [Int]
    public let isBoundary: Bool
    internal init(cell: UInt64, cellIndex: Int, oppositeNode: Int, nodes: [Int], boundary: Bool) {
        self.cell = cell; self.cellIndex = cellIndex; self.oppositeNode = oppositeNode
        self.nodes = nodes; self.isBoundary = boundary
    }
}
