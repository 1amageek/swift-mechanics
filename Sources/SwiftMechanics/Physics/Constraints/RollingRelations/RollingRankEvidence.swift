/// Rank of this three-row query on the complete supplied velocity layout, not a dynamics reaction solve.
public struct RollingRankEvidence: Sendable {
    public let rank: Int
    public let independentRowIDs: [UInt64]
    public let dependentRowIDs: [UInt64]
}
