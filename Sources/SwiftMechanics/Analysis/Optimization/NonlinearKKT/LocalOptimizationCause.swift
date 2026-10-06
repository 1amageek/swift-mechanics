public enum LocalOptimizationCause: Error, Sendable {
    case invalidProblem, unsupportedDomain, invalidSupplierOutput, invalidSupplierLedger, certificateRejected
    case capacity(required: Int,limit: Int)
    case rankDeficient(rank: Int,rows: Int)
    case rankIndeterminate(pivot: Double,threshold: Double)
    case weaklyActive(index: Int,multiplier: Double)
    case inactiveMargin(index: Int,slack: Double)
    case callback(NonlinearCause)
    case nonlinear(NonlinearFailure<Double>)
    case numerical(NumericalError)
}
