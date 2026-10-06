public struct StationaryIslandFailure: Error, Sendable {
    public let reason: StationaryIslandFailureReason
    public let supplierFailure: StationaryIslandFailureReason?
    public let knownWork: StationaryIslandWork
    public let failedSupplierWorkUnavailable: Bool
    internal init(_ reason: StationaryIslandFailureReason, supplierFailure: StationaryIslandFailureReason? = nil,
                  work: StationaryIslandWork, unavailable: Bool = false) {
        if case .supplierLedgerFailure(let original)=reason {
            self.reason=original.map { IslandArithmetic.cancelled($0) ? $0 : reason } ?? reason
            self.supplierFailure=original
        } else { self.reason=reason;self.supplierFailure=supplierFailure }
        knownWork=work
        failedSupplierWorkUnavailable=unavailable || work.failedSupplierWorkUnavailable
    }
}
