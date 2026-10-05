public struct FrictionalImpulseDiagnostics: Sendable {
    /// Original full W in row-major normal/first-tangent/second-tangent order, in inverse kilograms.
    public let delassus: [Double]
    /// Dimensionless shift in the scaled tangential disc solve; zero for sticking/frictionless.
    public let tangentMultiplier: Double
    public let momentumResidual: Double // Dimensionless under HybridPolicy.impulseScales.
    public let velocityResidual: Double // m/s.
    public let coulombResidual: Double // N s.
    public let workResidual: Double // J.
    public let energyResidual: Double // J.
    public let generalizedImpulseWorkJoules: Double
    public let contactImpulseWorkJoules: Double
    public let prescribedWallWorkJoules: Double
    public let normalLossJoules: Double
    public let tangentLossJoules: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    public let contactWork: ContactWork
}
