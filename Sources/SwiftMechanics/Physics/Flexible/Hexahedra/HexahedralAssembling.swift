public protocol HexahedralAssembling: Sendable {
    func assemble(_ mesh: ValidatedHexahedralMesh, state: HexahedralNodalState, massForm: FlexibleMassForm,
                  constitutiveWork: inout HexahedralConstitutiveWork,
                  work: inout NumericalWork) throws(HexahedralError) -> HexahedralAssembly
}
