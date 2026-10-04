public protocol TetrahedralAssembling: Sendable {
    func assemble(_ mesh: ValidatedTetrahedralMesh, state: NodalState, massForm: FlexibleMassForm,
                  constitutiveWork: inout ConstitutiveCallWork, work: inout NumericalWork) throws(FlexibleError) -> FlexibleAssembly
}
