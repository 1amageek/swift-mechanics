public struct LinearEstimatorClock: Equatable, Sendable {
    public let epochSeconds: Double
    public let periodSeconds: Double
    public let maximumTick: UInt64
    public init(epochSeconds: Double, periodSeconds: Double, maximumTick: UInt64) {
        self.epochSeconds = epochSeconds; self.periodSeconds = periodSeconds; self.maximumTick = maximumTick
    }
}
