public struct Tet4FieldSample: Sendable {
    public let snapshot: Tet4FieldSnapshot
    public let location: Tet4FieldLocation
    public let field: Tet4CellField
    public let stressMeasure: FieldStressMeasure, projection: FieldProjection
    public let stress: Matrix3
    public let referencePosition: Vector3, currentPosition: Vector3, displacement: Vector3, velocity: Vector3
    public let policy: FieldOutputPolicy, numericalWork: NumericalWork
    internal init(snapshot: Tet4FieldSnapshot, location: Tet4FieldLocation, field: Tet4CellField,
                  measure: FieldStressMeasure, projection: FieldProjection, stress: Matrix3,
                  referencePosition: Vector3, currentPosition: Vector3, displacement: Vector3, velocity: Vector3,
                  policy: FieldOutputPolicy, work: NumericalWork) {
        self.snapshot = snapshot; self.location = location; self.field = field
        self.stressMeasure = measure; self.projection = projection; self.stress = stress
        self.referencePosition = referencePosition; self.currentPosition = currentPosition
        self.displacement = displacement; self.velocity = velocity; self.policy = policy; self.numericalWork = work
    }
}
