public struct JointStopFailure: Error, Sendable {
    public let cause: JointStopCause
    public let failedSupplierWorkUnavailable: Bool
    public init(_ cause: JointStopCause, failedSupplierWorkUnavailable: Bool = false) {
        self.cause=cause; self.failedSupplierWorkUnavailable=failedSupplierWorkUnavailable
    }
}
