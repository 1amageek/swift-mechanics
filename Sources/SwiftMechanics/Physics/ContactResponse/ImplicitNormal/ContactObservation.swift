public struct ContactObservation: Sendable {
    public let coordinateID: UInt64
    public let firstBody: ModelReference, secondBody: ModelReference, frame: ModelReference
    public let firstFeature: CollisionFeature, secondFeature: CollisionFeature
    public let pointA: Vector3, pointB: Vector3
    public let intervalStart: Double, intervalEnd: Double
    public let normalForce: Double, trialSeparation: Double, normalVelocity: Double
    public let forceOnB: Vector3
    /// Endpoint-force equivalent impulse over the declared finite interval; not an impact impulse.
    public let equivalentImpulseOnB: Vector3
    /// Both wrenches are expressed in frame axes about the world frame origin.
    public let wrenchOnA: SpatialWrench, wrenchOnB: SpatialWrench
    public let active: ContactActiveState
    public let lawResponse: ContactResponse
}
