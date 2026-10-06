public enum ImplicitMethodCause: Error, Sendable {
    case invalidInput
    case unsupportedDomain
    case invalidEvaluation
    case invalidOwnerAccess
    case numerical(NumericalError)
    case runtime(RuntimeFailure)
    case nonlinear(NonlinearFailure<Double>)
}
