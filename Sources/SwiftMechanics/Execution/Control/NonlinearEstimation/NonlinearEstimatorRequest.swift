public struct NonlinearEstimatorRequest: Sendable {
    public let targetTimeSeconds: Double
    public let heldEffortNewtons: Double
    public let substeps: Int
    /// Discrete normalized 2x2 Q added once after the declared full propagation interval.
    public let normalizedProcessCovariance: [Double]
    public let measurement: NonlinearEstimatorMeasurement?
    public init(targetTimeSeconds: Double, heldEffortNewtons: Double, substeps: Int,
                normalizedProcessCovariance: [Double], measurement: NonlinearEstimatorMeasurement?) {
        self.targetTimeSeconds = targetTimeSeconds; self.heldEffortNewtons = heldEffortNewtons; self.substeps = substeps
        self.normalizedProcessCovariance = normalizedProcessCovariance; self.measurement = measurement
    }
}
