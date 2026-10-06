public enum CableEvolutionResult: Sendable {
    case accepted(state: NodalState, evidence: CableEvolutionEvidence)
    case rejected(original: NodalState, reason: CableError, work: NumericalWork)
}
