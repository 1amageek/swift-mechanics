public struct PlanarRootSupportWrench: Equatable, Sendable {
    public let rootBody: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    public let supportOnRoot: PlanarReactionWrench
    public let rootOnSupport: PlanarReactionWrench
    public let timeSeconds: Double
    public let revision: UInt64
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
}
