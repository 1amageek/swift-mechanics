public enum NumericalTermination: Equatable, Sendable {
    case accepted
    case invalidInput
    case unsupportedCapability
    case singularSystem
    case matrixClassFailure
    case nonConvergence
    case resourceLimit
    case cancelled
    case arithmeticFailure
}
