internal struct SurfaceTriangleFrame: Sendable {
    let origin: Vector3, firstEdge: Vector3, secondEdge: Vector3, normal: Vector3
    let doubleArea: Double
}
