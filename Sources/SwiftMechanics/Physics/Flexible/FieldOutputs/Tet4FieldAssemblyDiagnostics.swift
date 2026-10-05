public struct Tet4FieldAssemblyDiagnostics: Sendable {
    public let snapshot: Tet4FieldSnapshot
    public let assembly: FlexibleAssembly
    public let maximumNodalForceResidual: Double, energyResidual: Double
    public let resultantForceResidual: Double, resultantMomentResidual: Double
    public let policy: FieldOutputPolicy, numericalWork: NumericalWork
    internal init(snapshot: Tet4FieldSnapshot, assembly: FlexibleAssembly, force: Double, energy: Double,
                  resultant: Double, moment: Double, policy: FieldOutputPolicy, work: NumericalWork) {
        self.snapshot = snapshot; self.assembly = assembly; self.maximumNodalForceResidual = force
        self.energyResidual = energy; self.resultantForceResidual = resultant; self.resultantMomentResidual = moment
        self.policy = policy; self.numericalWork = work
    }
}
