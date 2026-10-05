public struct ArticulatedDynamicsFailure: Error, Sendable {
    public let cause: ArticulatedDynamicsCause
    public let failedSupplierWorkUnavailable: Bool
    public init(_ cause: ArticulatedDynamicsCause, failedSupplierWorkUnavailable: Bool = false) {
        self.cause = cause; self.failedSupplierWorkUnavailable = failedSupplierWorkUnavailable
    }
}
