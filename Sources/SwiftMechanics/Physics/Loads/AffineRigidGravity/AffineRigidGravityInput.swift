/// Retains the actual producer snapshot and complete supplied body-frame COM inertia.
public struct AffineRigidGravityInput: Sendable {
    public let snapshot: KinematicSnapshot
    public let inertia: RigidBodyInertia
    public let field: AffineGravity
    public let expectedRevision: UInt64
    public let expectedTimeSeconds: Double
    /// Declared partial derivative of G in the stationary world axes, in s^-3.
    public let gradientTimeDerivative: Matrix3

    public init(snapshot: KinematicSnapshot, inertia: RigidBodyInertia, field: AffineGravity,
                expectedRevision: UInt64, expectedTimeSeconds: Double, gradientTimeDerivative: Matrix3) {
        self.snapshot = snapshot; self.inertia = inertia; self.field = field
        self.expectedRevision = expectedRevision; self.expectedTimeSeconds = expectedTimeSeconds
        self.gradientTimeDerivative = gradientTimeDerivative
    }
}
