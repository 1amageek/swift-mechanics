public struct HeightfieldQueryPolicy: Sendable {
    public let geometry: CollisionQueryPolicy
    public let maximumTriangleEdgeMeters: Double

    public init(geometry: CollisionQueryPolicy, maximumTriangleEdgeMeters: Double) throws(HeightfieldError) {
        guard maximumTriangleEdgeMeters.isFinite, maximumTriangleEdgeMeters > 0 else { throw .invalidPolicy }
        self.geometry = geometry
        self.maximumTriangleEdgeMeters = maximumTriangleEdgeMeters
    }
}
