public struct FluidBalance: Equatable, Sendable {
    public let maximumMomentumResidual: Double
    public let maximumPressureGradientResidual: Double
    public let kineticEnergy: Double
    public let viscousPower: Double
    public let sourcePower: Double
    public let boundaryPower: Double
    public let numericalDissipation: Double
    public let energyDefect: Double?
    public let powerDefect: Double?
}
