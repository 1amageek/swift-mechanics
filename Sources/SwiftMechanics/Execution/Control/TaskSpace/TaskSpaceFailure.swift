public struct TaskSpaceFailure: Error, Sendable {
    public let cause: TaskSpaceCause
    public let failedSupplierWorkUnavailable: Bool
    public init(_ cause: TaskSpaceCause, failedSupplierWorkUnavailable: Bool = false) {
        self.cause = cause; self.failedSupplierWorkUnavailable = failedSupplierWorkUnavailable
    }
}
