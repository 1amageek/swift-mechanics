public struct NonlinearEstimatorCheckpoint: Sendable {
    public let plant: PrismaticEstimationModel
    public let timeSeconds: Double
    public let positionMeters: Double, rateMetersPerSecond: Double
    /// Row-major normalized 2x2 P: physical covariance is diag(scales)*P*diag(scales).
    public let normalizedCovariance: [Double]
    public let updateSequence: UInt64
    public let lastObservationSequence: UInt64?
}
