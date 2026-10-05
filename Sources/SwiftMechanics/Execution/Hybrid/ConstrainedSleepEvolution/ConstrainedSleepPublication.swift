internal final class ConstrainedSleepPublication: Sendable {
    let source:RuntimeCheckpoint
    let physical:KinematicState
    let records:[RuntimeContributorState]
    let impact:ConstrainedNormalImpulseResult?
    init(source:RuntimeCheckpoint,physical:KinematicState,records:[RuntimeContributorState],impact:ConstrainedNormalImpulseResult?) { self.source=source;self.physical=physical;self.records=records;self.impact=impact }
}
