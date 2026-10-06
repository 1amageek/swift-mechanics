public enum InertialParameterError: Error, Sendable {
    case invalidInput
    case invalidShape
    case staleMapping
    case topologyChange
    case forceDerivativeUnavailable
    case unsupportedDomain
    case capacityExceeded
    case cancelled
    case nonFiniteResult
    case originalResidualRejected(value: Double, threshold: Double)
    case core(CoreError)
    case model(ModelError)
    case numerical(NumericalError)
    case derivative(DerivativeError)
    case dynamics(DynamicsError)
    case joints(JointError)
    case unexpectedSupplierFailure
}
