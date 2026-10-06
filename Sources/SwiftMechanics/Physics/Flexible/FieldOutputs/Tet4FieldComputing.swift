public protocol Tet4FieldComputing: Sendable {
    func evaluate(source: Tet4FieldSource, state: NodalState, timeSeconds: Double, geometryRevision: UInt64,
                  previous: Tet4FieldSnapshot?, policy: FieldOutputPolicy, work: inout NumericalWork,
                  constitutiveWork: inout FieldConstitutiveWork) throws(FieldOutputError) -> Tet4FieldSnapshot
    func sample(_ snapshot: Tet4FieldSnapshot, location: Tet4FieldLocation, measure: FieldStressMeasure,
                projection: FieldProjection, policy: FieldOutputPolicy,
                work: inout NumericalWork) throws(FieldOutputError) -> Tet4FieldSample
    func average(_ snapshot: Tet4FieldSnapshot, selectedCells: [UInt64], measure: FieldStressMeasure,
                 projection: FieldProjection, averaging: FieldAveragingPolicy, policy: FieldOutputPolicy,
                 work: inout NumericalWork) throws(FieldOutputError) -> Tet4FieldAverage
    func assemblyDiagnostics(_ snapshot: Tet4FieldSnapshot, massForm: FlexibleMassForm,
                             policy: FieldOutputPolicy, work: inout NumericalWork,
                             constitutiveWork: inout ConstitutiveCallWork) throws(FieldOutputError) -> Tet4FieldAssemblyDiagnostics
}
