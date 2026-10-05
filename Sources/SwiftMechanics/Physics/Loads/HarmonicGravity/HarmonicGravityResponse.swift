public struct HarmonicGravityResponse: Sendable, Equatable {
    public let load: FramedPointLoad
    public let time: Double
    public let forcePositionDerivative: Matrix3
    public let explicitPotentialTimeDerivative: Double
    public let mechanicalPower: Double
    public let potentialRate: Double
    internal init(load: FramedPointLoad, time: Double, forcePositionDerivative: Matrix3,
                  explicitPotentialTimeDerivative: Double, mechanicalPower: Double, potentialRate: Double) {
        self.load = load; self.time = time; self.forcePositionDerivative = forcePositionDerivative
        self.explicitPotentialTimeDerivative = explicitPotentialTimeDerivative
        self.mechanicalPower = mechanicalPower; self.potentialRate = potentialRate
    }
}
