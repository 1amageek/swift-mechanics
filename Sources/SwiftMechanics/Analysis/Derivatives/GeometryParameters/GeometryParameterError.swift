public enum GeometryParameterError: Error, Sendable {
    case invalidInput
    case invalidShape
    case capacityExceeded
    case cancelled
    case nonFiniteResult
    case derivativeUnavailable(GeometryDerivativeRefusal)
    case originalPrimalMismatch
    case originalResidualRejected(value: Double, threshold: Double)
    case numerical(NumericalError)
    case scalar(DerivativeError)
    case core(CoreError)
    case joints(JointError, failedSupplierWorkUnavailable: Bool)
    case unexpectedSupplierFailure
}
