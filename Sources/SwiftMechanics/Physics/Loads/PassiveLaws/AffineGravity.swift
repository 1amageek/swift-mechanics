/// Declared acceleration field at one instant, g(x)=a+G*x. Gradient units 1/s^2.
public struct AffineGravity: Equatable, Sendable {
    public let frame: EntityID
    public let accelerationAtOrigin: Vector3
    public let gradient: Matrix3
    public let uniformTimeDerivative: Vector3
    public init(frame: EntityID, accelerationAtOrigin: Vector3, gradient: Matrix3 = .zero,
                uniformTimeDerivative: Vector3 = .zero) throws(LoadError) {
        guard frame.kind == .frame else { throw .invalidInput }
        guard gradient.m01 == gradient.m10, gradient.m02 == gradient.m20, gradient.m12 == gradient.m21 else { throw .invalidPassiveLaw }
        self.frame = frame; self.accelerationAtOrigin = accelerationAtOrigin; self.gradient = gradient
        self.uniformTimeDerivative = uniformTimeDerivative
    }
}
