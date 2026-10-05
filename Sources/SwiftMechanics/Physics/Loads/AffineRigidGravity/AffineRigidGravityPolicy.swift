public struct AffineRigidGravityPolicy: Equatable, Sendable {
    public let maximumBodies: Int
    public let maximumIdentityBytes: Int
    /// Absolute tolerance is W; relative tolerance is dimensionless.
    public let powerAgreement: NumericalTolerance

    public init(maximumBodies: Int, maximumIdentityBytes: Int,
                powerAgreement: NumericalTolerance) throws(AffineRigidGravityFailure) {
        guard maximumBodies > 0, maximumIdentityBytes >= 0 else { throw .invalidInput }
        self.maximumBodies = maximumBodies; self.maximumIdentityBytes = maximumIdentityBytes
        self.powerAgreement = powerAgreement
    }
}
