public final class Tet4RefinementSource: Sendable {
    public let mesh: ValidatedTetrahedralMesh
    public let state: NodalState
    public let timeSeconds: Double, geometryRevision: UInt64
    public init(mesh: ValidatedTetrahedralMesh, state: NodalState, timeSeconds: Double,
                geometryRevision: UInt64) throws(RefinementError) {
        guard timeSeconds.isFinite, timeSeconds >= 0 else { throw .invalidInput }
        self.mesh = mesh; self.state = state; self.timeSeconds = timeSeconds; self.geometryRevision = geometryRevision
    }
}
