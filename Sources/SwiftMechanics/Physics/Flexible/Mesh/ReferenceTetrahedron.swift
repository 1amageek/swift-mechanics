public struct ReferenceTetrahedron: Sendable {
    public let cell: TetrahedronCell
    public let materialIndex: Int
    public let volume: Double
    public let inverseEdges: Matrix3
    public let gradient0: Vector3
    public let gradient1: Vector3
    public let gradient2: Vector3
    public let gradient3: Vector3
    internal func gradient(_ node: Int) -> Vector3 {
        switch node { case 0: return gradient0; case 1: return gradient1; case 2: return gradient2; default: return gradient3 }
    }
}
