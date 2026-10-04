
public struct IMUObservation: Sendable {
    public let header:ObservationHeader
    public let sensorToWorld:RigidTransform
    public let angularVelocitySensor:Vector3
    public let specificForceSensor:Vector3
    public let worldAcceleration:Vector3
    public let angularVelocityUnit = PhysicalDimension(time:-1,angle:1)
    public let specificForceUnit = PhysicalDimension.acceleration
}
