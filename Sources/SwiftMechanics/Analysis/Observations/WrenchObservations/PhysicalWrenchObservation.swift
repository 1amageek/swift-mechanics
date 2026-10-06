
public struct PhysicalWrenchObservation: Sendable {
    public let header:ObservationHeader
    public let path:EntityID
    public let sensorToWorld:RigidTransform
    /// Torque/force or angular/linear impulse about the sensor origin in sensor axes.
    public let wrench:SpatialWrench
    public let options:WrenchObservationOptions
    public let forceUnit:PhysicalDimension
    public let torqueUnit:PhysicalDimension
    public let fidelity = "supplied-identified-physical-path"
}
