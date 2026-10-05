public protocol HexahedralMeshValidating: Sendable {
    func validate(_ mesh: HexahedralMesh, admission: HexahedralAdmission,
                  work: inout NumericalWork) throws(HexahedralError) -> ValidatedHexahedralMesh
}
