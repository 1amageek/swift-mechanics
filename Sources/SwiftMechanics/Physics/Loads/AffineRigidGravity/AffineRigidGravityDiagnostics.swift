/// Original continuum rates and independently evaluated origin/COM work identities.
public struct AffineRigidGravityDiagnostics: Equatable, Sendable {
    public let secondMomentBody: Matrix3
    public let secondMomentWorld: Matrix3
    public let secondMomentWorldRate: Matrix3
    public let secondMomentPotential: Double
    public let forcePositionDerivative: Matrix3
    public let mechanicalPower: Double
    public let bodyOriginPower: Double
    public let prescribedPower: Double
    public let virtualPower: Double
    public let explicitPotentialTimeDerivative: Double
    public let potentialTimeDerivative: Double
    public let originTransportResidual: Double
    public let conservativePowerResidual: Double

    internal init(secondMomentBody: Matrix3, secondMomentWorld: Matrix3, secondMomentWorldRate: Matrix3,
                  secondMomentPotential: Double, forcePositionDerivative: Matrix3,
                  mechanicalPower: Double, bodyOriginPower: Double, prescribedPower: Double, virtualPower: Double,
                  explicitPotentialTimeDerivative: Double, potentialTimeDerivative: Double,
                  originTransportResidual: Double, conservativePowerResidual: Double) {
        self.secondMomentBody = secondMomentBody; self.secondMomentWorld = secondMomentWorld
        self.secondMomentWorldRate = secondMomentWorldRate; self.secondMomentPotential = secondMomentPotential
        self.forcePositionDerivative = forcePositionDerivative; self.mechanicalPower = mechanicalPower
        self.bodyOriginPower = bodyOriginPower; self.prescribedPower = prescribedPower; self.virtualPower = virtualPower
        self.explicitPotentialTimeDerivative = explicitPotentialTimeDerivative
        self.potentialTimeDerivative = potentialTimeDerivative
        self.originTransportResidual = originTransportResidual; self.conservativePowerResidual = conservativePowerResidual
    }
}
