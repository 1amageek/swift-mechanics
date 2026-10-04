
public enum NonlinearMetric<Scalar: NumericalScalar>: Sendable {
    case available(Scalar)
    case unavailable(MetricUnavailableReason)
}
