public enum TaskSpaceSingularityPolicy: Sendable {
    case requireFullRowRank
    /// Dimensionless damping of the normalized operational Gram matrix.
    case damped(lambda: Double)
}
