public struct PolynomialSpringDamper: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let restCoordinate: Double
    public let quadraticStiffness: Double
    public let quarticStiffness: Double
    public let linearDamping: Double
    public let cubicDamping: Double
    public let maximumDisplacement: Double
    public let maximumRate: Double
    public init(coordinateKind: ScalarCoordinateKind, restCoordinate: Double,
                quadraticStiffness: Double, quarticStiffness: Double = 0,
                linearDamping: Double, cubicDamping: Double = 0,
                maximumDisplacement: Double, maximumRate: Double) throws(LoadError) {
        guard restCoordinate.isFinite, quadraticStiffness.isFinite, quarticStiffness.isFinite,
              linearDamping.isFinite, cubicDamping.isFinite, maximumDisplacement.isFinite, maximumRate.isFinite,
              quadraticStiffness >= 0, quarticStiffness >= 0, linearDamping >= 0, cubicDamping >= 0,
              maximumDisplacement > 0, maximumRate >= 0 else { throw .invalidPassiveLaw }
        self.coordinateKind = coordinateKind; self.restCoordinate = restCoordinate
        self.quadraticStiffness = quadraticStiffness; self.quarticStiffness = quarticStiffness
        self.linearDamping = linearDamping; self.cubicDamping = cubicDamping
        self.maximumDisplacement = maximumDisplacement; self.maximumRate = maximumRate
    }
}
