
public struct FrameMotionComposer: FrameMotionComposing, Sendable {
    public init() {}

    public func composed(parent: FrameMotion, relative: FrameMotion) throws -> FrameMotion {
        let offset = try parent.pose.rotation.rotating(relative.pose.translation)
        let omegaRelative = try parent.pose.rotation.rotating(relative.velocity.angular)
        let velocityRelative = try parent.pose.rotation.rotating(relative.velocity.linear)
        let omega = parent.velocity.angular
        let alpha = parent.acceleration.angular
        let velocity = SpatialMotion(
            angular: try omega.adding(omegaRelative),
            linear: try parent.velocity.linear.adding(omega.cross(offset)).adding(velocityRelative))
        let acceleration = SpatialMotion(
            angular: try alpha.adding(parent.pose.rotation.rotating(relative.acceleration.angular))
                .adding(omega.cross(omegaRelative)),
            linear: try parent.acceleration.linear.adding(alpha.cross(offset))
                .adding(omega.cross(omega.cross(offset)))
                .adding(omega.cross(velocityRelative).scaled(by: 2))
                .adding(parent.pose.rotation.rotating(relative.acceleration.linear)))
        return FrameMotion(pose: try parent.pose.composed(with: relative.pose), velocity: velocity, acceleration: acceleration)
    }

    public func inverted(_ frame: FrameMotion) throws -> FrameMotion {
        let inverse = try frame.pose.inverted()
        let omega = frame.velocity.angular, alpha = frame.acceleration.angular
        let translation = frame.pose.translation
        let velocity = SpatialMotion(
            angular: try inverse.rotation.rotating(omega).scaled(by: -1),
            linear: try inverse.rotation.rotating(omega.cross(translation).subtracting(frame.velocity.linear)))
        let acceleration = SpatialMotion(
            angular: try inverse.rotation.rotating(alpha).scaled(by: -1),
            linear: try inverse.rotation.rotating(alpha.cross(translation)
                .adding(omega.cross(frame.velocity.linear).scaled(by: 2))
                .subtracting(omega.cross(omega.cross(translation))).subtracting(frame.acceleration.linear)))
        return FrameMotion(pose: inverse, velocity: velocity, acceleration: acceleration)
    }
}
