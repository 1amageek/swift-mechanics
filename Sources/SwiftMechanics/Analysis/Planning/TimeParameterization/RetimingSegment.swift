public struct RetimingSegment: Sendable {
    public let index: Int
    public let startTime: Double
    public let endTime: Double
    public let duration: Double
    /// Analytic lower bound before the declared duration safety envelope.
    public let analyticDurationLowerBound: Double
    public let coordinates: [RetimingCoordinateCertificate]
    public let speedExtremumFraction = 0.5
    public let positiveAccelerationExtremumFraction = (3.0 - 3.0.squareRoot()) / 6
    public let negativeAccelerationExtremumFraction = (3.0 + 3.0.squareRoot()) / 6
    internal init(index: Int, startTime: Double, endTime: Double, duration: Double,
                  analyticDurationLowerBound: Double, coordinates: [RetimingCoordinateCertificate]) {
        self.index = index; self.startTime = startTime; self.endTime = endTime; self.duration = duration
        self.analyticDurationLowerBound = analyticDurationLowerBound; self.coordinates = coordinates
    }
}
