public struct NonlinearEstimatorMeasurement: Sendable {
    public let encoder: JointEncoderObservation
    public let deliveryTimeSeconds: Double
    public let sequence: UInt64
    public let positionVarianceSquareMeters: Double
    public init(encoder: JointEncoderObservation, deliveryTimeSeconds: Double, sequence: UInt64, positionVarianceSquareMeters: Double) {
        self.encoder = encoder; self.deliveryTimeSeconds = deliveryTimeSeconds; self.sequence = sequence
        self.positionVarianceSquareMeters = positionVarianceSquareMeters
    }
}
