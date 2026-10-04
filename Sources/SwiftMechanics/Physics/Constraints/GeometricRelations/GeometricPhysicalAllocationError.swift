public enum GeometricPhysicalAllocationError: Error, Sendable {
    case invalidPolicy, staleSource, cancelled
    case ambiguousPhysicalRow(row: UInt64)
    case geometry(GeometricConstraintError), constraint(ConstraintError), numerical(NumericalError)
    public var failedSupplierWorkUnavailable: Bool {
        switch self {
        case .geometry(let error): return error.failedSupplierWorkUnavailable
        case .constraint(let error):
            switch error {
            case .linear(_,let unavailable): return unavailable
            case .nonlinear(let failure): return failure.failedSupplierWorkUnavailable
            default: return false
            }
        default: return false
        }
    }
}
