public enum EquationError: Error, Equatable, Sendable {
    case outsideDomain
    case invalidDerivative
    case evaluationFailed(code: Int)
}
