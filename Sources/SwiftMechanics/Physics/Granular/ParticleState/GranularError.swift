public enum GranularError: Error, Sendable {
    case invalidInput, invalidBinding, staleCheckpoint, invalidSupplierOutput, arithmeticFailure, cancelled
    case capacity(resource: String, limit: Int)
    case unsupportedDomain
    case residual(value: Double, threshold: Double)
    case core(CoreError), numerical(NumericalError), runtime(RuntimeFailure)
    case collision(CollisionError, failedSupplierWorkUnavailable: Bool)
    case contact(ContactLawError, failedSupplierWorkUnavailable: Bool)
    case invalidSupplierLedger(supplier: String)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .collision(_,let unavailable), .contact(_,let unavailable): unavailable
        case .invalidSupplierLedger: true
        default: false
        }
    }
}
