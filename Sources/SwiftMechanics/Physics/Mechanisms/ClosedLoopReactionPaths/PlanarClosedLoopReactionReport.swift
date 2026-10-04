public struct PlanarClosedLoopReactionReport: Sendable {
    public let source: PlanarClosedLoopReactionInput
    public let originalAllocation: GeometricPhysicalAllocationWitness
    public var originalRows: GeometricPhysicalRowWitness { originalAllocation.rows }
    public var originalRank: ConstraintRankEvidence { originalAllocation.originalRank }
    public var physicalWrenchesUnique: Bool { originalAllocation.physicalWrenchesUnique }
    public var multipliersUnique: Bool { originalAllocation.multipliersUnique }
    public let loops: [PlanarLoopRowReaction]
    public let tree: PlanarTreeReactionReport
    public let maximumOriginalPositionResidual: Double
    public let maximumOriginalVelocityResidual: Double
    public let maximumOriginalAccelerationResidual: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    public let temporalMeaning: ReactionTemporalMeaning = .instantaneousContinuousForce
    public var topologyAssumption: ClosedLoopReactionTopology { source.topology }
}
