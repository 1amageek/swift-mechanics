public struct ConstrainedImpactPolicy: Sendable {
    public let impact: HybridPolicy
    public let constraints: ConstraintSolvePolicy
    public let dynamics: DynamicsSolvePolicy
    public let maximumFactorEntries: Int
    public let minimumEffectiveInverseMass: Double
    public init(impact: HybridPolicy, constraints: ConstraintSolvePolicy, dynamics: DynamicsSolvePolicy,
                maximumFactorEntries: Int, minimumEffectiveInverseMass: Double) throws(ConstrainedImpactError) {
        guard maximumFactorEntries > 0, minimumEffectiveInverseMass.isFinite, minimumEffectiveInverseMass > 0,
              constraints.evaluation.maximumCoordinates <= impact.maximumVelocities else { throw ConstrainedImpactError(.invalidInput) }
        self.impact = impact; self.constraints = constraints; self.dynamics = dynamics
        self.maximumFactorEntries = maximumFactorEntries; self.minimumEffectiveInverseMass = minimumEffectiveInverseMass
    }
}
