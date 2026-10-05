internal struct ConvexProjection: Sendable {
    let vertices: [ConvexSimplexVertex]
    let weights: [Double]
    let point: Vector3
}
