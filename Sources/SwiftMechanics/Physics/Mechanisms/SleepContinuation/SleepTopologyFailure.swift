@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public struct SleepTopologyFailure: Error, Sendable {
    public let reason:SleepTopologyFailureReason
    public let lastAccepted:RuntimeAcceptedState
    public let knownWork:NumericalWork
    public let failedSupplierWorkUnavailable:Bool
    internal init(_ reason:SleepTopologyFailureReason,source:RuntimeAcceptedState,work:NumericalWork) {
        self.reason=reason;lastAccepted=source;knownWork=work
        switch reason {
        case .supplierWorkUnavailable:failedSupplierWorkUnavailable=true
        case .runtime(let error):failedSupplierWorkUnavailable=error.failedSupplierWorkUnavailable
        case .mechanism(let error):failedSupplierWorkUnavailable=error.failedSupplierWorkUnavailable
        default:failedSupplierWorkUnavailable=false
        }
    }
}
