public struct LoopRowReaction: Sendable {
    public let rowID: UInt64
    public let kind: GeometricRelation.Kind
    public let normalizationScale: Double
    /// Continuous-force energy multiplier in joules, not an impulse multiplier.
    public let multiplierJoules: Double
    public let firstBody: EntityID
    public let secondBody: EntityID
    public let firstEndpointWorld: Vector3
    public let secondEndpointWorld: Vector3
    public let frame: EntityID
    /// Both signs share this torque reference, expressed in frame and in world coordinates.
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    public let secondOnFirst: SpatialWrench
    public let firstOnSecond: SpatialWrench
    public let timeSeconds: Double
    public let revision: UInt64
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
}
