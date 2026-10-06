public struct StribeckFrictionLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let coulombEffort: Double
    public let lowSpeedEffort: Double
    public let stribeckRate: Double
    public let regularizationRate: Double
    public let viscousCoefficient: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, coulombEffort: Double, lowSpeedEffort: Double, stribeckRate: Double, regularizationRate: Double, viscousCoefficient: Double, maximumRate: Double) throws(LoadError) {
        guard coulombEffort.isFinite, coulombEffort >= 0, lowSpeedEffort.isFinite, lowSpeedEffort >= 0, stribeckRate.isFinite, stribeckRate > 0, regularizationRate.isFinite, regularizationRate > 0, viscousCoefficient.isFinite, viscousCoefficient >= 0, maximumRate.isFinite, maximumRate > 0 else { throw .invalidPassiveLaw }
        guard lowSpeedEffort >= coulombEffort else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind
        self.coulombEffort = coulombEffort
        self.lowSpeedEffort = lowSpeedEffort
        self.stribeckRate = stribeckRate
        self.regularizationRate = regularizationRate
        self.viscousCoefficient = viscousCoefficient
        self.maximumRate = maximumRate
    }
}
