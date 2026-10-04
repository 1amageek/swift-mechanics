
public enum NonlinearCause: Error, Equatable, Sendable {
    case numerical(NumericalError)
    case equation(EquationError)
    case equationMetadataChanged
    case invalidEvaluation
    case invalidDerivative(error: Double, threshold: Double)
    case denseFillLimit(required: Int, limit: Int)
    case noAcceptableStep
    case originalResidualDisagreement(internalNorm: Double, originalNorm: Double, threshold: Double)
}
