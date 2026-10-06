public struct NonlinearEstimatorPolicy: Sendable {
    public let dynamics: DynamicsSolvePolicy
    public let derivatives: DerivativePolicy
    public let observations: ObservationPolicy
    public let covarianceCapability: LinearCapability
    public let covarianceTolerance: LinearTolerance<Double>
    public let physicalAgreement: NumericalTolerance
    public let covarianceSymmetry: NumericalTolerance
    public let maximumSubsteps: Int, maximumDerivativeCalls: Int, maximumScalarStorage: Int, maximumMetadataBytes: Int
    public let maximumIntervalSeconds: Double, maximumEffortNewtons: Double
    public let maximumCoordinateMagnitudeMeters: Double, maximumRateMagnitudeMetersPerSecond: Double
    public let maximumNormalizedCovarianceMagnitude: Double, maximumNormalizedInnovationSquared: Double
    public let isCancelled: @Sendable () -> Bool
    public init(dynamics: DynamicsSolvePolicy, derivatives: DerivativePolicy, observations: ObservationPolicy,
                covarianceCapability: LinearCapability, covarianceTolerance: LinearTolerance<Double>,
                physicalAgreement: NumericalTolerance, covarianceSymmetry: NumericalTolerance,
                maximumSubsteps: Int, maximumDerivativeCalls: Int, maximumScalarStorage: Int, maximumMetadataBytes: Int,
                maximumIntervalSeconds: Double, maximumEffortNewtons: Double, maximumCoordinateMagnitudeMeters: Double,
                maximumRateMagnitudeMetersPerSecond: Double, maximumNormalizedCovarianceMagnitude: Double,
                maximumNormalizedInnovationSquared: Double, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(NonlinearEstimatorCause) {
        let limits = [maximumIntervalSeconds, maximumEffortNewtons, maximumCoordinateMagnitudeMeters,
                      maximumRateMagnitudeMetersPerSecond, maximumNormalizedCovarianceMagnitude, maximumNormalizedInnovationSquared]
        guard maximumSubsteps > 0, maximumDerivativeCalls >= 0, maximumScalarStorage > 0, maximumMetadataBytes > 0,
              limits.allSatisfy({ $0.isFinite && $0 > 0 }), dynamics.coordinateScales == [1], dynamics.energyScale == 1,
              dynamics.timeScale == 1, covarianceCapability.precision == .float64,
              covarianceCapability.backend == .referenceCPU, covarianceCapability.algorithm == .cholesky else { throw .invalidPolicy }
        self.dynamics = dynamics; self.derivatives = derivatives; self.observations = observations
        self.covarianceCapability = covarianceCapability; self.covarianceTolerance = covarianceTolerance
        self.physicalAgreement = physicalAgreement; self.covarianceSymmetry = covarianceSymmetry
        self.maximumSubsteps = maximumSubsteps; self.maximumDerivativeCalls = maximumDerivativeCalls
        self.maximumScalarStorage = maximumScalarStorage; self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumIntervalSeconds = maximumIntervalSeconds; self.maximumEffortNewtons = maximumEffortNewtons
        self.maximumCoordinateMagnitudeMeters = maximumCoordinateMagnitudeMeters; self.maximumRateMagnitudeMetersPerSecond = maximumRateMagnitudeMetersPerSecond
        self.maximumNormalizedCovarianceMagnitude = maximumNormalizedCovarianceMagnitude; self.maximumNormalizedInnovationSquared = maximumNormalizedInnovationSquared
        self.isCancelled = isCancelled
    }
}
