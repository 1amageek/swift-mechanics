public struct ClosedLoopReactionReport: Sendable {
    public let source: ClosedLoopReactionInput
    public let originalRows: GeometricPhysicalRowWitness
    public let originalRank: ConstraintRankEvidence
    public let loops: [LoopRowReaction]
    public let tree: TreeReactionReport
    public let maximumOriginalPositionResidual: Double
    public let maximumOriginalVelocityResidual: Double
    public let maximumOriginalAccelerationResidual: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
    /// Source's caller declaration, not an independently established completeness certificate.
    public var topologyAssumption: ClosedLoopReactionTopology { source.topology }
}
