public struct GeometricPhysicalAllocationPolicy: Sendable {
    public let rows: GeometricPhysicalRowPolicy
    public let rank: ConstraintSolvePolicy
    public init(rows: GeometricPhysicalRowPolicy, rank: ConstraintSolvePolicy) throws(GeometricPhysicalAllocationError) {
        guard case .allowRedundancy = rank.rankPolicy,
              rows.evaluation.expectedLayoutRevision == rank.evaluation.expectedLayoutRevision else { throw .invalidPolicy }
        self.rows=rows;self.rank=rank
    }
}
