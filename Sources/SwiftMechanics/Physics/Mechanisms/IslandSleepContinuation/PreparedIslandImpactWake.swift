@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class PreparedIslandImpactWake: Sendable {
    public let source:RuntimeCheckpoint
    public let physical:KinematicState
    public let sleep:RuntimeContributorState
    public let integration:RuntimeContributorState
    public let affectedIslandIDs:[UInt64]
    public let eventID:UInt64
    internal let owner:IslandCheckpointedMechanismSleep
    internal init(owner:IslandCheckpointedMechanismSleep,source:RuntimeCheckpoint,physical:KinematicState,sleep:RuntimeContributorState,integration:RuntimeContributorState,affected:[UInt64],eventID:UInt64) { self.owner=owner;self.source=source;self.physical=physical;self.sleep=sleep;self.integration=integration;affectedIslandIDs=affected;self.eventID=eventID }
}
