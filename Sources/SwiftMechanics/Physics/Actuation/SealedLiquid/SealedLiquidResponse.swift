public struct SealedLiquidResponse: Equatable, Sendable {
    public let stroke: Double, volume: Double, pressure: Double, force: Double, forceDerivative: Double
    /// Mechanical potential relative to stroke zero, including ambient-pressure work.
    public let potentialEnergy: Double
}
