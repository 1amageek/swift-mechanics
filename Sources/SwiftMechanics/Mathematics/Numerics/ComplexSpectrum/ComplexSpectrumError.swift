public enum ComplexSpectrumError: Error, Sendable {
    case invalidInput, invalidPolicy, capacityExceeded, nonFiniteResult, cancelled
    case numerical(NumericalError)
    case nonConvergence(iterations: Int, residual: Double)
    case illConditionedEigenvector(index: Int)
    case residualRejected(value: Double, threshold: Double)
}
