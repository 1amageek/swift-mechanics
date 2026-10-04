/// Pose rotation direction is a right-trivialized body tangent. Other vectors use the sample reference frame.
public struct FrameMotionDirection: Equatable, Sendable {
    public let translation: Vector3
    public let rotationTangent: Vector3
    public let angularVelocity: Vector3
    public let linearVelocity: Vector3
    public let angularAcceleration: Vector3
    public let linearAcceleration: Vector3
    public init(translation: Vector3 = .zero, rotationTangent: Vector3 = .zero,
                angularVelocity: Vector3 = .zero, linearVelocity: Vector3 = .zero,
                angularAcceleration: Vector3 = .zero, linearAcceleration: Vector3 = .zero) {
        self.translation=translation; self.rotationTangent=rotationTangent; self.angularVelocity=angularVelocity; self.linearVelocity=linearVelocity
        self.angularAcceleration=angularAcceleration; self.linearAcceleration=linearAcceleration
    }
}
