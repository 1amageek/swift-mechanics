public struct PlanarJointReactionWrench: Equatable, Sendable {
    public let joint: EntityID
    public let parentBody: EntityID
    public let childBody: EntityID
    public let frame: EntityID
    /// Both signs share this actual point; its z is retained without transverse moment authority.
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    public let parentOnChild: PlanarReactionWrench
    public let childOnParent: PlanarReactionWrench
    public let timeSeconds: Double
    public let revision: UInt64
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
}
