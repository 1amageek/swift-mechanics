@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class PreparedIslandSmoothEndpoint: Sendable {
    public let source:RuntimeCheckpoint
    public let physical:KinematicState
    public let sleep:RuntimeContributorState
    public let integration:RuntimeContributorState
    internal let owner:IslandCheckpointedMechanismSleep
    internal init(owner:IslandCheckpointedMechanismSleep,source:RuntimeCheckpoint,physical:KinematicState,sleep:RuntimeContributorState,integration:RuntimeContributorState) {
        self.owner=owner;self.source=source;self.physical=physical;self.sleep=sleep;self.integration=integration
    }
}
