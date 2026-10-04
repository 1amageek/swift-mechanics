public enum PrescribedMotionError: Error, Sendable {
    case invalidInput, invalidFrame, invalidAxis, outsideDomain, staleSource, capacityExceeded, cancelled
    case mathematical(CoreError), numerical(NumericalError), supplierLedgerReplaced, supplierWorkUnavailable
    public var failedSupplierWorkUnavailable: Bool {
        switch self { case .supplierLedgerReplaced,.supplierWorkUnavailable: true; default: false }
    }
}
