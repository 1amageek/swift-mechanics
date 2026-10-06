internal struct HeightfieldTriangleProjection: Sendable {
    let point: Vector3
    let barycentric: HeightfieldBarycentric
    let distance: Double
    let feature: HeightfieldFeature
    let residual: Double
}
