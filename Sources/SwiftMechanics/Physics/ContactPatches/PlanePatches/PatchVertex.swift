internal struct PatchVertex: Sendable {
    var point: Vector3, weights: PatchBarycentricWeights, pressure: Double
    static let zero=Self(point:.zero,weights:.zero,pressure:0)
}
