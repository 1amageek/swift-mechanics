public final class MaterialSurface: Sendable {
    public let body: ModelReference
    public let mesh: ValidatedTetrahedralMesh
    public let triangles: [BoundaryTriangle]
    internal init(body: ModelReference, mesh: ValidatedTetrahedralMesh, triangles: [BoundaryTriangle]) { self.body=body; self.mesh=mesh; self.triangles=triangles }
}
