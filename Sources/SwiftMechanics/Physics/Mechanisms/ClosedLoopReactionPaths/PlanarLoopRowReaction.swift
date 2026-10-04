public struct PlanarLoopRowReaction: Sendable {
    public let rowID: UInt64
    public let kind: GeometricRelation.Kind
    public let normalizationScale: Double
    public let isStructuralZero: Bool
    /// The retained representative in joules; structural-zero multipliers remain nonunique.
    public let multiplierJoules: Double
    public let firstBody: EntityID
    public let secondBody: EntityID
    public let firstEndpointWorld: Vector3
    public let secondEndpointWorld: Vector3
    public let frame: EntityID
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    public let secondOnFirst: PlanarLoopWrench
    public let firstOnSecond: PlanarLoopWrench
    public let timeSeconds: Double
    public let revision: UInt64
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
}
