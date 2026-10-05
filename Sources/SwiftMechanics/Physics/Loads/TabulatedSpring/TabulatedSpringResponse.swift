public struct TabulatedSpringResponse: Equatable, Sendable {
    public let effort: Double
    public let potentialEnergy: Double
    public let leftCoordinateDerivative: Double?
    public let rightCoordinateDerivative: Double?
}
