public struct RollingConstraintRow: Sendable {
    public let rowID: UInt64
    public let kind: RollingRowKind
    /// A in A*v+drift and A*vdot+accelerationBias, in unscaled SI coordinates.
    public let coefficients: [Double]
    public let drift: Double
    public let accelerationBias: Double
    public let velocityResidual: Double
    public let accelerationResidual: Double
    public let velocityDecompositionResidual: Double
    public let accelerationDecompositionResidual: Double
    public let directionWorld: Vector3
    public let directionRateWorld: Vector3
    public let wheelPower: RollingPowerCovector
    public let planePower: RollingPowerCovector
}
