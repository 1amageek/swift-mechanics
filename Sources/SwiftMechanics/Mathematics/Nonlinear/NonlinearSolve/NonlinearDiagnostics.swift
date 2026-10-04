
public struct NonlinearDiagnostics<Scalar: NumericalScalar>: Sendable {
    public let nonlinearIterations: Int
    public let acceptedSteps: Int
    public let rejectedSteps: Int
    public let residualEvaluations: Int
    public let jacobianEvaluations: Int
    public let originalEvaluations: Int
    public let tangentPoint: [Scalar]?
    public let tangentRank: Int?
    public let conditionOneNorm: NonlinearMetric<Scalar>
    public let activeSetChanges: MetricUnavailableReason
    public let constraintRank: MetricUnavailableReason
    public let feasibility: MetricUnavailableReason
    public let optimality: MetricUnavailableReason
    public let lastStepFraction: Scalar?
    public let lastTrustRatio: Scalar?
    public let work: NumericalWork
}
