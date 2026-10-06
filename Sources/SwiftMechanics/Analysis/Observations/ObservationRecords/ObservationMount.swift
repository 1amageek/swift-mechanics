
public struct ObservationMount: Sendable {
    public let sensor: EntityID
    public let body: EntityID
    public let sensorFrame: EntityID
    /// Maps sensor coordinates to body coordinates; fixed for this observation.
    public let sensorToBody: RigidTransform
    public init(sensor: EntityID, body: EntityID, sensorFrame: EntityID, sensorToBody: RigidTransform) throws(ObservationError) {
        guard sensor.kind == .sensor,body.kind == .body,sensorFrame.kind == .frame else { throw .invalidMounting }
        self.sensor=sensor;self.body=body;self.sensorFrame=sensorFrame;self.sensorToBody=sensorToBody
    }
}
