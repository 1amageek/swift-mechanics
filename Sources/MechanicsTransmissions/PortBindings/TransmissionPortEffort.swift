import MechanicsCore

public struct TransmissionPortEffort: Sendable {
    public let binding: TransmissionPortBinding
    public let axisInReference: Vector3
    public let generalizedEffort: Double
    /// Conjugate scalar power; actual-body power additionally requires its twist/drift.
    public let power: Double
    /// Common-frame origin wrench from this current axial port, not bearing reactions.
    public let wrenchAboutReferenceOrigin: SpatialWrench
}
