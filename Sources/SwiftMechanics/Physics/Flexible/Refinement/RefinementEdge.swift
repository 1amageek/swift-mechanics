/// Global original-node identity pair, ordered lexicographically by identifiers.
public struct RefinementEdge: Equatable, Sendable {
    public let lowerIdentifier: UInt64, upperIdentifier: UInt64
    public let lowerNode: Int, upperNode: Int
    internal init(lowerIdentifier: UInt64, upperIdentifier: UInt64, lowerNode: Int, upperNode: Int) {
        self.lowerIdentifier = lowerIdentifier; self.upperIdentifier = upperIdentifier
        self.lowerNode = lowerNode; self.upperNode = upperNode
    }
}
