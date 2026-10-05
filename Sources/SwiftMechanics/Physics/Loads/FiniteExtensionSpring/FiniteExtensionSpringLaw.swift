public struct FiniteExtensionSpringLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let restCoordinate: Double
    public let stiffness: Double
    public let limitingExtension: Double
    public let maximumDisplacement: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, restCoordinate: Double, stiffness: Double, limitingExtension: Double, maximumDisplacement: Double, maximumRate: Double) throws(LoadError) {
        guard restCoordinate.isFinite, stiffness.isFinite, stiffness > 0, limitingExtension.isFinite, limitingExtension > 0, maximumDisplacement.isFinite, maximumDisplacement > 0, maximumRate.isFinite, maximumRate >= 0 else { throw .invalidPassiveLaw }
        guard maximumDisplacement < limitingExtension else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind
        self.restCoordinate = restCoordinate
        self.stiffness = stiffness
        self.limitingExtension = limitingExtension
        self.maximumDisplacement = maximumDisplacement
        self.maximumRate = maximumRate
    }
}
