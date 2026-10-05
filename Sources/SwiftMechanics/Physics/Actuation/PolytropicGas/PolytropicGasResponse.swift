public struct PolytropicGasResponse: Equatable, Sendable {
    public let stroke: Double, volume: Double, pressure: Double, force: Double, forceDerivative: Double
    /// Mechanical potential of the declared polytrope; thermal internal energy is not inferred.
    public let potentialEnergy: Double
}
