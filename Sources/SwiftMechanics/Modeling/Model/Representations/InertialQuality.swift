public enum InertialQuality: Equatable, Sendable {
    case exact
    case approximation(InertialApproximation)
}
