public struct ExponentialSpringLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let restCoordinate: Double
    public let stiffness: Double
    public let lengthScale: Double
    public let maximumDisplacement: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, restCoordinate: Double, stiffness: Double, lengthScale: Double, maximumDisplacement: Double, maximumRate: Double) throws(LoadError) {
        guard restCoordinate.isFinite, stiffness.isFinite, stiffness > 0, lengthScale.isFinite, lengthScale > 0, maximumDisplacement.isFinite, maximumDisplacement > 0, maximumRate.isFinite, maximumRate >= 0 else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind
        self.restCoordinate = restCoordinate
        self.stiffness = stiffness
        self.lengthScale = lengthScale
        self.maximumDisplacement = maximumDisplacement
        self.maximumRate = maximumRate
    }
}
