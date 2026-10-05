@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class IslandSleepTrajectoryEndpoint: Sendable {
    public let source:RuntimeCheckpoint
    public let accepted:RuntimeAcceptedState
    public let privateAcceptedSteps:Int
    public var physical:KinematicState { accepted.checkpoint.physical }
    internal let owner:IslandCheckpointedMechanismSleep
    internal init(owner:IslandCheckpointedMechanismSleep,source:RuntimeCheckpoint,accepted:RuntimeAcceptedState,steps:Int) { self.owner=owner;self.source=source;self.accepted=accepted;privateAcceptedSteps=steps }
}
