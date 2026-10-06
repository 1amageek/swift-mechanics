public struct ValidatedHexahedralMesh: Sendable {
    public let mesh: HexahedralMesh
    public let scalarStorage: Int
    internal let referenceCells: [ReferenceHexahedron]
    internal let admission: HexahedralAdmission

    internal init(mesh: HexahedralMesh, scalarStorage: Int, referenceCells: [ReferenceHexahedron],
                  admission: HexahedralAdmission) {
        self.mesh = mesh
        self.scalarStorage = scalarStorage
        self.referenceCells = referenceCells
        self.admission = admission
    }
}
