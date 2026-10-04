
public enum ConstraintError: Error, Sendable {
    case invalidInput, invalidDimensions, staleLayout, outsideDomain, nonFiniteResult, capacityExceeded, cancelled
    case rankAmbiguity(rank: Int, rows: Int)
    case inconsistent(rowID: UInt64, residual: Double)
    case correctionExceeded(value: Double, limit: Double)
    case rankChanged
    case unsupportedDomain
    case numerical(NumericalError)
    case nonlinear(NonlinearFailure<Double>)
    case linear(NumericalError, failedSupplierWorkUnavailable: Bool)
    case joints(JointError)
}
