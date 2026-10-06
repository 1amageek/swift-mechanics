public struct HeightfieldSphereOverlap: Sendable {
    public enum Kind: Equatable, Sendable {
        case separated
        case boundaryTouching
        case surfaceIntersection
    }

    public let kind: Kind
    public let surface: HeightfieldPoint
    public let sphere: CollisionGeometryIdentity
    public let spherePose: RigidTransform
    public let sphereBoundaryPoint: Vector3
    /// Ball-to-surface clearance, not solid penetration depth.
    public let clearance: Double
    public let approximationError: Double
    public let originalBalanceResidual: Double
}
