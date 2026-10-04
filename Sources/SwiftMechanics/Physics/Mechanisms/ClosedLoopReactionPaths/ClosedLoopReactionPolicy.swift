public struct ClosedLoopReactionPolicy: Sendable {
    public let maximumRows: Int
    public let geometry: GeometricPhysicalRowPolicy
    public let rank: ConstraintSolvePolicy
    public let tree: TreeReactionPolicy
    public let admission: DynamicsAdmission
    public let positionTolerance: Double
    public let velocityTolerance: Double
    public let accelerationTolerance: Double
    public init(maximumRows: Int, geometry: GeometricPhysicalRowPolicy, rank: ConstraintSolvePolicy,
                tree: TreeReactionPolicy, admission: DynamicsAdmission,
                positionTolerance: Double, velocityTolerance: Double, accelerationTolerance: Double) throws(ClosedLoopReactionError) {
        guard maximumRows > 0, positionTolerance.isFinite, positionTolerance >= 0,
              velocityTolerance.isFinite, velocityTolerance >= 0, accelerationTolerance.isFinite, accelerationTolerance >= 0,
              case .allowRedundancy = rank.rankPolicy else { throw .invalidInput }
        self.maximumRows=maximumRows; self.geometry=geometry; self.rank=rank; self.tree=tree; self.admission=admission
        self.positionTolerance=positionTolerance; self.velocityTolerance=velocityTolerance; self.accelerationTolerance=accelerationTolerance
    }
}
