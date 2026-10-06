public struct HydroelasticPatch: Sendable {
    public let first: HydroelasticCellSelection
    public let second: HydroelasticPartner
    public let frame: EntityID, origin: Vector3
    /// Gradient(pB-pA) direction for two fields; supplied plane normal for a rigid partner.
    public let normal: Vector3?
    public let triangles: [HydroelasticTriangle]
    public let firstNodalForces: [Vector3]
    /// Nil means that the selected partner is rigid and has no flexible nodal layout.
    public let secondNodalForces: [Vector3]?
    public let wrenchOnFirst: SpatialWrench, wrenchOnSecond: SpatialWrench
    public let area: Double, integratedPressure: Double
    public let firstPower: Double, secondPower: Double, totalPower: Double
    public let originalForceResidual: Double, originalMomentResidual: Double, originalPowerResidual: Double
    public let originalGeometryResidual: Double, originalPressureDifferencePascals: Double
    public let work: NumericalWork
}
