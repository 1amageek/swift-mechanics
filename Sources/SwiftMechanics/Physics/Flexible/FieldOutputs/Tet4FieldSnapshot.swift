public final class Tet4FieldSnapshot: Sendable {
    public let source: Tet4FieldSource
    public let state: NodalState
    public let timeSeconds: Double, geometryRevision: UInt64
    public let cells: [Tet4CellField]
    public let nodalDisplacements: [Vector3], internalForces: [Vector3]
    public let storedEnergy: Double, internalPower: Double
    public let forceResidual: Double, momentResidual: Double, powerResidual: Double
    /// Current first-node position, the explicit origin of resultant moment diagnostics.
    public let momentReferencePosition: Vector3
    public let policy: FieldOutputPolicy
    public let numericalWork: NumericalWork, constitutiveWork: FieldConstitutiveWork
    internal init(source: Tet4FieldSource, state: NodalState, time: Double, revision: UInt64,
                  cells: [Tet4CellField], displacement: [Vector3], forces: [Vector3], energy: Double,
                  power: Double, forceResidual: Double, momentResidual: Double, powerResidual: Double,
                  policy: FieldOutputPolicy, work: NumericalWork, calls: FieldConstitutiveWork) {
        self.source = source; self.state = state; self.timeSeconds = time; self.geometryRevision = revision
        self.cells = cells; self.nodalDisplacements = displacement; self.internalForces = forces
        self.storedEnergy = energy; self.internalPower = power; self.forceResidual = forceResidual
        self.momentResidual = momentResidual; self.powerResidual = powerResidual
        self.momentReferencePosition = state.positions[0]
        self.policy = policy; self.numericalWork = work; self.constitutiveWork = calls
    }
}
