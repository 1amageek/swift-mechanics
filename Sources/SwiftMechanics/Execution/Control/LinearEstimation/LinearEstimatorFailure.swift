public final class LinearEstimatorFailure: Error, Sendable {
    public let cause: LinearEstimatorError
    public let prefix: LinearEstimatorState?
    public let admittedWork: NumericalWork
    public init(cause: LinearEstimatorError, prefix: LinearEstimatorState?, admittedWork: NumericalWork) {
        self.cause = cause; self.prefix = prefix; self.admittedWork = admittedWork
    }
}
