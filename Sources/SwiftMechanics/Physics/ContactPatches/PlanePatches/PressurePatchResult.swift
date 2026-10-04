public struct PressurePatchResult: Sendable {
    public let compliantBody: ModelReference, rigidBody: ModelReference, frame: ModelReference
    public let meshRevision: UInt64, pressureRevision: UInt64, planeRevision: UInt64
    public let source: SourceProvenance, materialIdentifiers: [EntityID]
    public let origin: Vector3, triangles: [PressureTriangle], nodalForces: [Vector3]
    public let area: Double, integratedPressure: Double
    public let wrenchOnCompliant: SpatialWrench, wrenchOnRigid: SpatialWrench
    public let compliantPower: Double, rigidPower: Double, totalPower: Double
    public let originalForceResidual: Double, originalMomentResidual: Double, originalPowerResidual: Double
    public let work: NumericalWork
}
