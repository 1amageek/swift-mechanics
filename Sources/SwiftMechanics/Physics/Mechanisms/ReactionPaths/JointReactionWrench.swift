public struct JointReactionWrench: Equatable, Sendable {
    public let joint: EntityID
    public let parentBody: EntityID
    public let childBody: EntityID
    public let frame: EntityID
    /// Torque reference point expressed in frame; both signs use this same point.
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    /// Continuous force/torque exerted by parent on child (N, N m).
    public let parentOnChild: SpatialWrench
    /// Continuous force/torque exerted by child on parent at the same reference.
    public let childOnParent: SpatialWrench
    public let timeSeconds: Double
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
    public let revision: UInt64
}
