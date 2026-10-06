/// Caller-attributed calibration for actual supplied physical nodal pressure.
/// This record does not certify a constitutive equilibrium or infer pressure from elasticity.
public struct HydroelasticCalibration: Sendable {
    public enum Fidelity: Sendable { case suppliedPhysicalNodalPressure }
    public let source: SourceProvenance
    public let material: EntityID
    public let materialSource: SourceProvenance
    public let fidelity: Fidelity
    public let declaredPressureApproximationPascals: Double
    public let declaredGeometryApproximationMeters: Double
    public init(source: SourceProvenance, material: EntityID, materialSource: SourceProvenance,
                declaredPressureApproximationPascals: Double, declaredGeometryApproximationMeters: Double) throws(HydroelasticError) {
        guard material.kind == .material, declaredPressureApproximationPascals.isFinite, declaredPressureApproximationPascals >= 0,
              declaredGeometryApproximationMeters.isFinite, declaredGeometryApproximationMeters >= 0 else { throw .invalidInput }
        self.source=source; self.material=material; self.materialSource=materialSource
        self.fidelity = .suppliedPhysicalNodalPressure
        self.declaredPressureApproximationPascals=declaredPressureApproximationPascals
        self.declaredGeometryApproximationMeters=declaredGeometryApproximationMeters
    }
}
