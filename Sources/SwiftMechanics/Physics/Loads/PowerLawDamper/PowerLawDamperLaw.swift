public struct PowerLawDamperLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let coefficient: Double
    public let exponent: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, coefficient: Double, exponent: Double, maximumRate: Double) throws(LoadError) {
        guard coefficient.isFinite, coefficient >= 0, exponent.isFinite, exponent >= 1, maximumRate.isFinite, maximumRate > 0 else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind
        self.coefficient = coefficient
        self.exponent = exponent
        self.maximumRate = maximumRate
    }
}
