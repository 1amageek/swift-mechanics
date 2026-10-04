public final class StationaryAffineMotion: Sendable {
    public let system:RigidDynamicsSystem
    public let rows:VelocityConstraintSample
    public let motion:ConstrainedMotion
    internal init(system:RigidDynamicsSystem,rows:VelocityConstraintSample,motion:ConstrainedMotion) { self.system=system;self.rows=rows;self.motion=motion }
}
