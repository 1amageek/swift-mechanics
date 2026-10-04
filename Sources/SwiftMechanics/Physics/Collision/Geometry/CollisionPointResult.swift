
public struct CollisionPointResult: Sendable {
    public let geometry: CollisionGeometryIdentity
    public let boundaryPoint: Vector3
    public let outwardNormal: Vector3
    public let signedDistance: Double
    public let feature: CollisionFeature
    public let degeneracy: CollisionDegeneracy
}
