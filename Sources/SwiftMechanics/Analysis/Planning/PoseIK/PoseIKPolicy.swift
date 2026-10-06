public struct PoseIKPolicy: Sendable {
    public let maximumCoordinates: Int
    public let maximumRows: Int
    public let maximumBodies: Int
    public let maximumIdentityBytes: Int
    public let maximumDerivativeCallsPerDirection: Int
    public let loopTolerance: Double
    public let rankRelativeTolerance: Double
    public let joint: JointEvaluationPolicy
    public let derivative: DerivativePolicy
    public let nonlinear: NonlinearPolicy<Double>
    /// Total operation budget, including admission, nonlinear work and final original acceptance.
    public let budget: NumericalBudget
    public let isCancelled: @Sendable () -> Bool

    public init(maximumCoordinates: Int, maximumRows: Int, maximumBodies: Int, maximumIdentityBytes: Int,
                maximumDerivativeCallsPerDirection: Int, loopTolerance: Double, rankRelativeTolerance: Double,
                joint: JointEvaluationPolicy, derivative: DerivativePolicy, nonlinear: NonlinearPolicy<Double>,
                budget: NumericalBudget, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(PoseIKError) {
        guard maximumCoordinates > 0, maximumRows > 0, maximumBodies > 0, maximumIdentityBytes > 0, maximumIdentityBytes < Int.max,
              maximumDerivativeCallsPerDirection > 0, loopTolerance.isFinite, loopTolerance >= 0,
              rankRelativeTolerance.isFinite, rankRelativeTolerance > 0, rankRelativeTolerance < 1 else { throw .invalidPolicy }
        self.maximumCoordinates = maximumCoordinates; self.maximumRows = maximumRows; self.maximumBodies = maximumBodies
        self.maximumIdentityBytes = maximumIdentityBytes; self.maximumDerivativeCallsPerDirection = maximumDerivativeCallsPerDirection
        self.loopTolerance = loopTolerance; self.rankRelativeTolerance = rankRelativeTolerance
        self.joint = joint; self.derivative = derivative; self.nonlinear = nonlinear; self.budget = budget; self.isCancelled = isCancelled
    }
}
