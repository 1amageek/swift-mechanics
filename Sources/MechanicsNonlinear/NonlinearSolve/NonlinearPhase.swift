public enum NonlinearPhase: Equatable, Sendable {
    case validation, initialResidual, workspace, iteration, jacobian, linearSolve, conditioning, derivativeProbe, trial, originalAcceptance
}
