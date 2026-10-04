public enum OptimizationCause: Error, Sendable {
    case invalidProblem, unsupportedDomain, nonFiniteResult, invalidSupplierOutput
    case rankIndeterminate(pivot: Double, threshold: Double)
    case dependentEqualityRows(rank: Int, rows: Int)
    case capacity(resource: String, required: Int, limit: Int)
    case nonconverged(processed: Int, limit: Int)
    case certificateRejected
    case cancelled
    case numerical(NumericalError)
    case invalidSupplierLedger
}
