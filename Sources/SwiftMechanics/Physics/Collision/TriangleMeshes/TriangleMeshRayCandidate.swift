internal struct TriangleMeshRayCandidate: Sendable {
    let distance: Double
    let face: Int
    let weights: Vector3
}
