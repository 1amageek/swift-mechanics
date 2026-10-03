import MechanicsCore
public struct GravityResponse: Equatable, Sendable {
    public let load: FramedPointLoad
    public let forcePositionDerivative: Matrix3
    public let explicitPotentialTimeDerivative: Double
    internal init(load: FramedPointLoad, forcePositionDerivative: Matrix3, explicitPotentialTimeDerivative: Double) {
        self.load = load; self.forcePositionDerivative = forcePositionDerivative
        self.explicitPotentialTimeDerivative = explicitPotentialTimeDerivative
    }
}
