public struct TabulatedDamperResponse: Equatable, Sendable {
    public let effort: Double
    public let dissipatedPower: Double
    public let leftRateDerivative: Double?
    public let rightRateDerivative: Double?
}
