public struct GranularStepResult: Sendable {
    public let state: GranularState
    public let neighbors: [GranularNeighbor]
    public let contacts: [GranularContactObservation]
    public let boundaryReactions: [GranularBoundaryReaction]
    public let evidence: GranularStepEvidence
    internal init(state: GranularState, neighbors: [GranularNeighbor], contacts: [GranularContactObservation], boundaryReactions: [GranularBoundaryReaction], evidence: GranularStepEvidence) {
        self.state=state; self.neighbors=neighbors; self.contacts=contacts; self.boundaryReactions=boundaryReactions; self.evidence=evidence
    }
}
