import MechanicsCore

public struct CollisionRayHit: Sendable {
    public let geometry: CollisionGeometryIdentity
    public let distance: Double
    public let point: Vector3
    public let outwardNormal: Vector3
    public let feature: CollisionFeature
}
