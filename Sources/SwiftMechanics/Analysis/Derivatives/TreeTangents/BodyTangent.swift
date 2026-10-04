public struct BodyTangent: Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let translation: Vector3
    public let rotationMatrix: Matrix3
    public let velocity: SpatialMotion
    public let acceleration: SpatialMotion
    public let prescribedDrift: SpatialMotion
    public let accelerationBias: SpatialMotion
}
