public struct ConstrainedImpactError: Error, Sendable {
    public let reason: ConstrainedImpactFailureReason
    /// An original failure retained when ledger corruption also refuses the invocation.
    public let supplierFailure: ConstrainedImpactFailureReason?
    public let failedSupplierWorkUnavailable: Bool
    public init(_ reason: ConstrainedImpactFailureReason, supplierFailure: ConstrainedImpactFailureReason? = nil,
                failedSupplierWorkUnavailable: Bool = false) {
        self.reason = reason; self.supplierFailure = supplierFailure
        self.failedSupplierWorkUnavailable = failedSupplierWorkUnavailable
    }
}
