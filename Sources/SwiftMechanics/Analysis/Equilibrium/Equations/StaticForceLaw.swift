/// Coefficients are SI derivatives of energy with respect to each published coordinate.
public enum StaticForceLaw: Equatable, Sendable {
    case springs(linear: [Double], cubic: [Double], constant: [Double], loadDirection: [Double])
    /// gravityMoment=m*g*l and appliedMoment are in N*m, coordinate in radians.
    case pendulum(gravityMoment: Double, appliedMoment: Double)
}
