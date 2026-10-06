
public struct MountedMotionObservation: Sendable {
    public let header: ObservationHeader
    public let sensorToWorld: RigidTransform
    /// Geometric derivatives at the sensor origin, expressed in world axes.
    public let velocity: SpatialMotion
    public let acceleration: SpatialMotion
    public let positionUnit = PhysicalDimension.length
    public let linearVelocityUnit = PhysicalDimension.velocity
    public let linearAccelerationUnit = PhysicalDimension.acceleration
    public let angularVelocityUnit = PhysicalDimension(time:-1,angle:1)
    public let angularAccelerationUnit = PhysicalDimension(time:-2,angle:1)
    internal init(header:ObservationHeader,motion:FrameMotion) {
        self.header=header;sensorToWorld=motion.pose;velocity=motion.velocity;acceleration=motion.acceleration
    }
}
