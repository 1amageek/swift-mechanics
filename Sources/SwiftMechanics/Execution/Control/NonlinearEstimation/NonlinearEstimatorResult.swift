public struct NonlinearEstimatorResult: Sendable {
    public let checkpoint: NonlinearEstimatorCheckpoint
    public let predictedPositionMeters: Double, predictedRateMetersPerSecond: Double
    public let normalizedTransition: [Double]
    public let predictedNormalizedCovariance: [Double]
    public let predictedEncoder: JointEncoderObservation
    public let normalizedInnovation: Double?
    public let normalizedInnovationVariance: Double?
    public let normalizedInnovationSquared: Double?
    public let normalizedGain: [Double]?
    public let work: NumericalWork
    public let derivativeCalls: Int
}
