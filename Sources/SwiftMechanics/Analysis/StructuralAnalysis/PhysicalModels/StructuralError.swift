public enum StructuralError: Error, Sendable {
    case invalidInput, capacityExceeded, staleBinding, cancelled, nonFiniteResult, nonsymmetric, nonPositiveMass
    case unsupportedDomain, outsideDomain, noCriticalBracket
    case residualRejected(value: Double, threshold: Double)
    case nonConvergence(iterations: Int, residual: Double)
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
    case flexible(FlexibleError)
}
