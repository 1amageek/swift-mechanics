public struct ManifoldProjectionFailure: Error, Sendable {
    public let cause: GeometricConstraintError
    public let lastPosition: [Double]
    public let work: NumericalWork
    public var failedSupplierWorkUnavailable: Bool { cause.failedSupplierWorkUnavailable }
    internal init(cause:GeometricConstraintError,position:[Double],work:NumericalWork) {
        self.cause=cause;lastPosition=position;self.work=work
    }
}
