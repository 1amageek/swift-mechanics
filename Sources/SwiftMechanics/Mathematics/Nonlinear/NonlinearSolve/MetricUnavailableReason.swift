public enum MetricUnavailableReason: Equatable, Sendable {
    case notRequested, notDefinedByEquationProvider, noTangentEvaluated
}
