/// Owns accepted immutable originals across noninline physical/recovery phase boundaries.
internal final class PlanarPrescribedRootReactionContext: Sendable {
    let source: PlanarPrescribedRootReactionInput
    let physical: PlanarReactionContext
    let original: HolonomicGeometrySample
    let constraint: PrescribedRootConstraint
    let rank: ConstraintRankEvidence
    let reaction: [Double]
    let rootEffort: [Double]
    init(source: PlanarPrescribedRootReactionInput, physical: PlanarReactionContext, original: HolonomicGeometrySample,
         constraint: PrescribedRootConstraint, rank: ConstraintRankEvidence, reaction: [Double], rootEffort: [Double]) {
        self.source=source;self.physical=physical;self.original=original;self.constraint=constraint
        self.rank=rank;self.reaction=reaction;self.rootEffort=rootEffort
    }
}
