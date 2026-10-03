public struct ValidatedTetrahedralMesh: Sendable {
    public let mesh: TetrahedralMesh
    public let referenceCells: [ReferenceTetrahedron]
    public let scalarStorage: Int
    internal init(mesh: TetrahedralMesh, referenceCells: [ReferenceTetrahedron], scalarStorage: Int) {
        self.mesh = mesh; self.referenceCells = referenceCells; self.scalarStorage = scalarStorage
    }
}
