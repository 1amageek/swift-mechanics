public struct IslandSleepFailure: Error, Sendable {
    public let reason: IslandSleepFailureReason
    public let accepted: RuntimeAcceptedState?
    public let supplierFailure:IslandSleepFailureReason?
    public let work: IslandSleepWork
    public var failedSupplierWorkUnavailable: Bool { work.failedSupplierWorkUnavailable || work.physical.failedSupplierWorkUnavailable }
    internal init(_ reason:IslandSleepFailureReason,accepted:RuntimeAcceptedState?,work:IslandSleepWork,supplierFailure:IslandSleepFailureReason? = nil) { self.reason=reason;self.accepted=accepted;self.work=work;self.supplierFailure=supplierFailure }
}
