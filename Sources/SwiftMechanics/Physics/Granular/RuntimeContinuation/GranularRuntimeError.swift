public enum GranularRuntimeError: Error, Sendable {
    case invalidInput, unsupportedDomain, staleSource, malformedJournal, capacityExceeded, cancelled
    case invalidSupplierEvidence, supplierLedgerReplaced
    case physical(GranularError), runtime(RuntimeFailure), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced: true
        case .physical(let error): error.failedSupplierWorkUnavailable
        case .runtime(let error): error.failedSupplierWorkUnavailable
        default: false
        }
    }
    internal func runtimeFailure(_ id: String) -> RuntimeFailure {
        let code: RuntimeFailureCode
        switch self {
        case .cancelled, .physical(.cancelled), .numerical(.cancelled): code = .cancelled
        case .capacityExceeded, .physical(.capacity), .numerical: code = .contributorBudgetExceeded
        case .staleSource: code = .incompatibleContinuation
        case .unsupportedDomain: code = .unsupportedDomain
        case .runtime(let error): return error
        default: code = .invalidContributor
        }
        return RuntimeFailure(code,contributor:id,message:"Granular original physics or bounded journal admission failed.",
            failedSupplierWorkUnavailable:failedSupplierWorkUnavailable)
    }
}
