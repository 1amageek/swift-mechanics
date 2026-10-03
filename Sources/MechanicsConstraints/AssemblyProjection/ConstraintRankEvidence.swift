public struct ConstraintRankEvidence: Sendable {
    public let rank: Int
    public let independentRows: [Int]
    public let dependentRowIDs: [UInt64]
    public let reactionNullity: Int
    /// Numerical injectivity of J-transpose only, conditional on a known generalized reaction.
    /// This does not infer any dynamic force or prove existence of a compatible reaction.
    public var reactionsUnique: Bool { reactionNullity == 0 }
    public init(rank: Int, independentRows: [Int], dependentRowIDs: [UInt64], reactionNullity: Int) {
        self.rank=rank; self.independentRows=independentRows; self.dependentRowIDs=dependentRowIDs; self.reactionNullity=reactionNullity
    }
}
