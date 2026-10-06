public enum LinearEstimatorError: Error, Equatable, Sendable {
    case invalidPolicy
    case invalidModel
    case invalidState
    case invalidInput
    case sourceMismatch
    case timingMismatch
    case unresolvedSample
    case missingObservation
    case delayedObservation
    case outOfOrderObservation
    case unobservable(rank: Int)
    case invalidCovariance(pivot: Int)
    case corruptContinuation
    case capacity
    case cancelled
    case numerical(NumericalError)
    case failedSupplierWorkUnavailable(NumericalError)
}
