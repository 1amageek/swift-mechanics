public enum ScalarCoordinateKind: Equatable, Sendable {
    /// Coordinate m, rate m/s, conjugate load N.
    case translation
    /// Coordinate rad, rate rad/s, conjugate load Nm/rad (radian numerical convention).
    case rotation
}
