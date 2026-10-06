public enum PoseIKError: Error, Sendable {
    case invalidPolicy
    case invalidInput
    case invalidShape
    case staleIdentity
    case capacityExceeded
    case outsideBounds(coordinate: UInt64)
    case unsupportedChart
    case unsupportedTask
    case unsupportedBranch
    case unsupportedTaskCount(rows: Int, coordinates: Int)
    case orientationBranch(row: UInt64, cosine: Double)
    case originalTaskRejected(row: UInt64, residual: Double, threshold: Double)
    case originalLoopRejected(row: UInt64, residual: Double, threshold: Double)
    case singularRows(rank: Int, rows: Int)
    case nonFiniteResult
    case cancelled
    case core(CoreError)
    case joints(JointError)
    case constraints(ConstraintError)
    case derivatives(DerivativeError)
    case numerical(NumericalError)
    case nonlinear(NonlinearFailure<Double>)
    case unexpectedSupplierFailure
}
