internal struct TriangleClosestFeature: Sendable {
    let point: Vector3
    let weights: Vector3
    let feature: TriangleMeshFeature
    let normal: Vector3
    let distance: Double
}
