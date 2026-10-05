public struct Tet4FieldAverage: Sendable {
    public let snapshot: Tet4FieldSnapshot
    public let selectedCells: [UInt64]
    public let stressMeasure: FieldStressMeasure, projection: FieldProjection
    public let averaging: FieldAveragingPolicy
    public let stress: Matrix3, greenStrain: Matrix3
    public let centroidDisplacement: Vector3
    /// Weighted mean of reference-volume energy densities; not a homogenized material energy.
    public let referenceEnergyDensity: Double
    public let selectedStoredEnergy: Double, totalWeight: Double
    public let policy: FieldOutputPolicy, numericalWork: NumericalWork
    internal init(snapshot: Tet4FieldSnapshot, selectedCells: [UInt64], measure: FieldStressMeasure,
                  projection: FieldProjection, averaging: FieldAveragingPolicy, stress: Matrix3,
                  strain: Matrix3, displacement: Vector3, density: Double, energy: Double, weight: Double,
                  policy: FieldOutputPolicy, work: NumericalWork) {
        self.snapshot = snapshot; self.selectedCells = selectedCells; self.stressMeasure = measure
        self.projection = projection; self.averaging = averaging; self.stress = stress; self.greenStrain = strain
        self.centroidDisplacement = displacement; self.referenceEnergyDensity = density
        self.selectedStoredEnergy = energy; self.totalWeight = weight; self.policy = policy; self.numericalWork = work
    }
}
