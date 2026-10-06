/// Frozen-basis partials of the selected constitutive branches, not an evolution Jacobian.
public struct ContactCurrentDerivatives: Sendable {
    public let normalForcePenetrationDerivative: Double
    public let normalForceVelocityDerivative: Double
    public let normalIsDifferentiable: Bool
    public let cohesiveForceSeparationDerivative: Double
    public let cohesionIsDifferentiable: Bool
    public let tangentialForceBristleDerivative: Double
    public let rollingFirstAngularDerivative: Double
    public let rollingCrossAngularDerivative: Double
    public let rollingSecondAngularDerivative: Double
    public let spinningAngularDerivative: Double
    public let coupleCompressiveLoadDerivative: Vector3
}
