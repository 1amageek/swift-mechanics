import MechanicsNumerics
public struct EquilibriumSweepReport: Sendable {
    public let cases: [EquilibriumCaseReport]
    public let continuation: EquilibriumContinuationState
    public let attemptedCases: Int
    public let acceptedCases: Int
    public let work: NumericalWork
}
