public struct RegularizedYieldDamperLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let yieldEffort: Double
    public let viscousCoefficient: Double
    public let regularizationRate: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, yieldEffort: Double, viscousCoefficient: Double, regularizationRate: Double, maximumRate: Double) throws(LoadError) {
        guard yieldEffort.isFinite, yieldEffort >= 0, viscousCoefficient.isFinite, viscousCoefficient >= 0, regularizationRate.isFinite, regularizationRate > 0, maximumRate.isFinite, maximumRate > 0 else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind
        self.yieldEffort = yieldEffort
        self.viscousCoefficient = viscousCoefficient
        self.regularizationRate = regularizationRate
        self.maximumRate = maximumRate
    }
}
