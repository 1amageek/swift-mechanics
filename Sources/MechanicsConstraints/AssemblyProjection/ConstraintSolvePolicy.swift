import MechanicsNumerics
import MechanicsNonlinear

public struct ConstraintSolvePolicy: Sendable {
    public let evaluation: ConstraintEvaluationPolicy
    public let diagonalMetric: [Double]
    public let energyScale: Double
    public let rankPolicy: ConstraintRankPolicy
    public let rankRelativeTolerance: Double
    public let originalResidualTolerance: Double
    public let maximumCorrection: Double
    public let nonlinear: NonlinearPolicy<Double>
    public let linearCapability: LinearCapability
    public let linearTolerance: LinearTolerance<Double>
    public init(evaluation: ConstraintEvaluationPolicy, diagonalMetric: [Double], energyScale: Double, rankPolicy: ConstraintRankPolicy,
                rankRelativeTolerance: Double, originalResidualTolerance: Double, maximumCorrection: Double, nonlinear: NonlinearPolicy<Double>,
                linearCapability: LinearCapability, linearTolerance: LinearTolerance<Double>) throws(ConstraintError) {
        guard energyScale.isFinite, energyScale > 0, rankRelativeTolerance.isFinite, rankRelativeTolerance > 0, rankRelativeTolerance < 1,
              originalResidualTolerance.isFinite, originalResidualTolerance >= 0, maximumCorrection.isFinite, maximumCorrection >= 0 else { throw .invalidInput }
        self.evaluation=evaluation; self.diagonalMetric=diagonalMetric; self.energyScale=energyScale; self.rankPolicy=rankPolicy
        self.rankRelativeTolerance=rankRelativeTolerance; self.originalResidualTolerance=originalResidualTolerance; self.maximumCorrection=maximumCorrection
        self.nonlinear=nonlinear; self.linearCapability=linearCapability; self.linearTolerance=linearTolerance
    }
}
