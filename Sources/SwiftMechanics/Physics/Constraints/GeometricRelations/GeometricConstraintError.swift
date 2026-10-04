public enum GeometricConstraintError: Error, Sendable {
    case invalidInput, invalidShape, staleSource, outsideDomain, unsupportedDomain, invalidChart
    case unsupportedPhysicalRows
    case invalidGeometry, nonFiniteResult, capacityExceeded, cancelled, rankChanged, zeroRank
    case branchViolation(row: UInt64)
    case originalRejected(row: UInt64)
    case correctionExceeded(value: Double, limit: Double)
    case iterationLimit
    case constraint(ConstraintError)
    case motion(PrescribedMotionError)
    case numerical(NumericalError)
    case supplierLedgerReplaced
    case supplierWorkUnavailable
    public var failedSupplierWorkUnavailable: Bool {
        switch self { case .supplierLedgerReplaced, .supplierWorkUnavailable: true; case .motion(let error): error.failedSupplierWorkUnavailable; case .constraint(.linear(_,let unavailable)): unavailable; case .constraint(.nonlinear(let failure)): failure.failedSupplierWorkUnavailable; default: false }
    }
}
