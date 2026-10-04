public enum TreeReactionTopology: Equatable, Sendable {
    /// Caller assumption: all unknown interactions are exactly tree edges and net root support admitted by the selected recovery port. No bearing or actuator split is inferred.
    case completeTree
    case unrepresentedConnections
}
