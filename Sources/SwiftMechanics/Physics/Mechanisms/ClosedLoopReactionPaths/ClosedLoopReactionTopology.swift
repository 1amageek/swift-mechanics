public enum ClosedLoopReactionTopology: Equatable, Sendable {
    /// Caller assumption: these original rows and the tree/root support inventory every unknown interaction.
    case completeTreeAndDeclaredRows
    case unrepresentedConnections
}
