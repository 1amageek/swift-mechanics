public enum EquilibriumCaseStatus: Sendable {
    case accepted(EquilibriumSolution)
    case failed(EquilibriumError)
    case notAttempted(EquilibriumError)
}
