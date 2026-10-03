import MechanicsNumerics
import MechanicsNonlinear
import MechanicsConstraints

public struct EquilibriumSolution: Sendable {
    public let model: StaticForceModel
    public let constraints: StaticConstraints?
    public let branch: EquilibriumBranch
    public let parameter: Double
    public let time: Double
    public let position: [Double]
    public let physicalGradient: [Double]
    public let generalizedReaction: [Double]
    public let rowMultipliers: [Double]
    public let originalForceResidual: [Double]
    public let originalConstraintResidual: [Double]
    public let energy: Double
    public let rank: ConstraintRankEvidence
    public let nonlinearDiagnostics: NonlinearDiagnostics<Double>
    public let work: NumericalWork
    /// Local stationarity only; no stability or global uniqueness assertion.
    public var termination: NumericalTermination { .accepted }
}
