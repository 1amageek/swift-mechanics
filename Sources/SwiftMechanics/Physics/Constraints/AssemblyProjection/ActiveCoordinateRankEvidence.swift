/// Restricted-map evidence, not force, feasibility or compiled physical source authority.
public struct ActiveCoordinateRankEvidence: Sendable {
    public let sample: VelocityConstraintSample
    public let activeCoordinates: [Int]
    public let policy: ConstraintSolvePolicy
    public let rank: ConstraintRankEvidence
    public var originalRowCount: Int { sample.rowIDs.count }
    public var originalCoordinateCount: Int { sample.layout.scales.count }
    public var activeCoordinateCount: Int { activeCoordinates.count }
    internal init(sample: VelocityConstraintSample, activeCoordinates: [Int], policy: ConstraintSolvePolicy,
                  rank: ConstraintRankEvidence) {
        self.sample = sample; self.activeCoordinates = activeCoordinates; self.policy = policy; self.rank = rank
    }
}
