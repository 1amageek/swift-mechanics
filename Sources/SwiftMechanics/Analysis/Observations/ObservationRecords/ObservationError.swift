
public enum ObservationError: Error, Sendable {
    case invalidInput, invalidMounting, unknownIdentity, staleSource, staleGravity, unsupportedChart
    case unsupportedDecomposition, unsupportedCompensation, temporalMismatch, missingAcceleration
    case capacityExceeded, cancelled, nonfinite, supplierLedgerReplaced, invalidSupplierEvidence
    case compilation(CompilationFailure)
    case numerical(NumericalError)
    case core(CoreError)
    case frameSupplierFailure
    public var failedSupplierWorkUnavailable: Bool {
        switch self { case .compilation, .frameSupplierFailure, .supplierLedgerReplaced: true; default: false }
    }
}
