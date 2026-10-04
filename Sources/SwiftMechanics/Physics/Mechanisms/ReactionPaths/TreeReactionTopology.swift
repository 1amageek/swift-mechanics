public enum TreeReactionTopology: Equatable, Sendable {
    /// Caller assumption: all unknown interactions are exactly the tree edges and fixed root support.
    case completeTree
    case unrepresentedConnections
}
