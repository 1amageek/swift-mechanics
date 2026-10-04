public enum DynamicsError: Error, Equatable, Sendable {
    case invalidInput
    case invalidShape
    case capacityExceeded
    case dimensionMismatch
    case nonplanarInput
    case supplierLedgerReplaced
    case unsupportedDomain
    case inertiaIdentityMismatch
    case frameMismatch
    case velocityMismatch
    case energyUnavailable
    case nonFiniteResult
    case cancelled
    case physicalResidualRejected(value: Double, threshold: Double)
    /// A failed frozen numerical supplier does not publish partial consumed work. No retry follows.
    case numerical(NumericalError, failedSupplierWorkUnavailable: Bool)
    case core(CoreError)
    case joints(JointError)
    case loads(LoadError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .supplierLedgerReplaced: return true
        case .numerical(_,let unavailable): return unavailable
        default: return false
        }
    }
}
