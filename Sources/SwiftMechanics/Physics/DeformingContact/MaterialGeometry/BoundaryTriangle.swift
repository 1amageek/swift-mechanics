public struct BoundaryTriangle: Equatable, Sendable {
    public let feature: SurfaceFeatureID
    public let nodes: [Int]
    internal init(feature: SurfaceFeatureID, nodes: [Int]) { self.feature=feature; self.nodes=nodes }
}
