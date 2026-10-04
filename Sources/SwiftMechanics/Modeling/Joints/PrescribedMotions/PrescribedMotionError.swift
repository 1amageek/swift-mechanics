public enum PrescribedMotionError: Error, Sendable {
    case invalidInput, invalidFrame, invalidAxis, outsideDomain, staleSource, capacityExceeded, cancelled
    case mathematical(CoreError), numerical(NumericalError), supplierLedgerReplaced, supplierWorkUnavailable
    case unsupportedChart, nonPlanarMotion
    case unsupportedDiscontinuity(time:Double,derivative:PrescribedTrajectoryDerivative)
    public var failedSupplierWorkUnavailable: Bool {
        switch self { case .supplierLedgerReplaced,.supplierWorkUnavailable: true; default: false }
    }
}
