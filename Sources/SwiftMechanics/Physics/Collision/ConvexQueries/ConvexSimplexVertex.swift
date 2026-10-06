internal struct ConvexSimplexVertex: Sendable {
    let first: ConvexSupport
    let second: ConvexSupport
    let difference: Vector3
}
