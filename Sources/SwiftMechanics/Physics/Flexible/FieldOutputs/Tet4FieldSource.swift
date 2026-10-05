/// Retains the exact qualified reference mesh owner used by every field operation.
public final class Tet4FieldSource: Sendable {
    public let mesh: ValidatedTetrahedralMesh
    public init(mesh: ValidatedTetrahedralMesh) { self.mesh = mesh }
}
