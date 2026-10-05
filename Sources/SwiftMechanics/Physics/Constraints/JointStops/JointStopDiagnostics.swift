public struct JointStopDiagnostics: Sendable {
    public let effectiveInverseMassPerKilogram: Double
    public let normalSpeedBeforeMetersPerSecond: Double
    public let normalSpeedAfterMetersPerSecond: Double
    public let normalRateResidualMetersPerSecond: Double
    public let normalizedMomentumResidual: Double
    public let normalLossJoules: Double
    public let generalizedImpulseWorkJoules: Double
    public let normalImpulseWorkJoules: Double
    public let workResidualJoules: Double
    public let energyResidualJoules: Double
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    public let contactWork: ContactWork
}
