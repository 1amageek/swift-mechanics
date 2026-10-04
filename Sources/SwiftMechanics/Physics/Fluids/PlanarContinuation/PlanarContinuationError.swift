
public enum PlanarContinuationError: Error, Equatable, Sendable {
    case invalidInput, capacity, malformedPayload, staleBinding, cancelled, supplierLedgerFailure
    case physical(PlanarFluidError)
    case runtime(RuntimeFailureCode)
}

internal func planarContinuationFailure(_ error: PlanarContinuationError, id: String) -> RuntimeFailure {
    let code: RuntimeFailureCode
    var unavailable = false
    switch error {
    case .supplierLedgerFailure: code = .invalidContributor; unavailable = true
    case .capacity: code = .contributorBudgetExceeded
    case .malformedPayload: code = .invalidContributor
    case .staleBinding: code = .incompatibleContinuation
    case .cancelled: code = .cancelled
    case .runtime(let actual): code = actual
    case .physical(let actual):
        switch actual {
        case .cancelled: code = .cancelled
        case .capacity: code = .contributorBudgetExceeded
        case .staleBinding: code = .incompatibleContinuation
        case .numerical(_, let unknown): code = .invalidContributor; unavailable = unknown
        default: code = .invalidContributor
        }
    case .invalidInput: code = .invalidContributor
    }
    return RuntimeFailure(code, contributor: id, message: "Planar field continuation rejected its input or physical evolution.",
                          failedSupplierWorkUnavailable: unavailable)
}
