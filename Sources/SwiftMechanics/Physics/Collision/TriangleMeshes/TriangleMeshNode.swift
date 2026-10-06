internal struct TriangleMeshNode: Sendable {
    let minimum: Vector3
    let maximum: Vector3
    let left: Int
    let right: Int
    let face: Int
}
