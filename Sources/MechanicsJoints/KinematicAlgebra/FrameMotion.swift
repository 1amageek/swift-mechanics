import MechanicsCore

public struct FrameMotion: Equatable, Sendable {
    public let pose: RigidTransform
    public let velocity: SpatialMotion
    public let acceleration: SpatialMotion

    public static let zeroMotion = SpatialMotion(angular: .zero, linear: .zero)

    /// Linear fields are geometric derivatives at the moving frame origin in parent axes.
    public init(pose: RigidTransform, velocity: SpatialMotion, acceleration: SpatialMotion) {
        self.pose = pose
        self.velocity = velocity
        self.acceleration = acceleration
    }

    public static func stationary(pose: RigidTransform) -> FrameMotion {
        FrameMotion(pose: pose, velocity: zeroMotion, acceleration: zeroMotion)
    }
}
