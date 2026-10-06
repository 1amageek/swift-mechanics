public enum ContactDerivativeError: Error, Sendable {
    case invalidInput
    case unsupportedDomain
    case nonsmoothBoundary
    case outsideDomain
    case primalMismatch
    case nonFiniteResult
    case cancelled
    case invalidSupplierLedger(failedSupplierWorkUnavailable: Bool)
    case law(ContactLawError)
    case core(CoreError)
}
