public struct RootSupportWrench: Equatable, Sendable {
    public let rootBody: EntityID
    public let frame: EntityID
    public let referencePoint: Vector3
    public let referencePointWorld: Vector3
    /// Continuous force/torque exerted by the support on the complete tree (N, N m).
    public let supportOnRoot: SpatialWrench
    public let rootOnSupport: SpatialWrench
    public let timeSeconds: Double
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
    public let revision: UInt64
}
