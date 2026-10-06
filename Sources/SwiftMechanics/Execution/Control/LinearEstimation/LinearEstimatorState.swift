public struct LinearEstimatorState: Sendable {
    public let model: LinearEstimatorModel
    public let tick: UInt64
    public let timeSeconds: Double
    public let mean: [Double]
    public let covariance: DenseMatrix<Double>
    public let sampleResolved: Bool
    public let lastObservationSequence: UInt64?
    public let lastObservationTimeSeconds: Double?
    internal init(model: LinearEstimatorModel, tick: UInt64, timeSeconds: Double, mean: [Double],
                  covariance: DenseMatrix<Double>, sampleResolved: Bool, lastObservationSequence: UInt64?,
                  lastObservationTimeSeconds: Double?) {
        self.model = model; self.tick = tick; self.timeSeconds = timeSeconds; self.mean = mean; self.covariance = covariance
        self.sampleResolved = sampleResolved; self.lastObservationSequence = lastObservationSequence
        self.lastObservationTimeSeconds = lastObservationTimeSeconds
    }
}
