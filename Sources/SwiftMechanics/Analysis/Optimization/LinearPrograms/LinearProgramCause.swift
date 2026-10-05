public enum LinearProgramCause: Error, Sendable {
    case invalidProblem
    case capacityExceeded
    case pivotLimit
    case numericalAmbiguity
    case certificateRejected
    case nonFiniteArithmetic
    case cancelled
    case numerical(NumericalError)
}
