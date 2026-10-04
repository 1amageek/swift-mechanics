public enum StationaryLoadError: Error, Sendable {
    case invalidInput, invalidCatalog, staleBinding, capacity, invocationLimit, busy, cancelled, supplierLedgerFailure, unsupportedDomain
    case loads(LoadError)
    public var failedSupplierWorkUnavailable: Bool { if case .supplierLedgerFailure = self { return true }; return false }
    public var isCancellation: Bool { if case .cancelled = self { return true }; if case .loads(.cancelled) = self { return true }; return false }
    public var runtimeFailure: RuntimeFailure {
        let code:RuntimeFailureCode
        switch self {
        case .cancelled,.loads(.cancelled):code = .cancelled
        case .capacity,.invocationLimit,.loads(.workExhausted),.loads(.capacityExceeded):code = .capacityExceeded
        case .supplierLedgerFailure:code = .invalidOwnerAccess
        case .invalidInput,.invalidCatalog:code = .invalidInput
        case .unsupportedDomain:code = .unsupportedDomain
        default:code = .invalidState
        }
        return RuntimeFailure(code,message:"Stationary load admission/evaluation failed.",failedSupplierWorkUnavailable:failedSupplierWorkUnavailable)
    }
}
