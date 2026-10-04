public struct PlanarStepEvidence: Equatable, Sendable {
    public let maximumCourantFactor:Double
    public let maximumAdvectiveFactor:Double
    public let viscousFactor:Double
    public let maximumMomentumResidual:Double
    public let meanMomentumResidualX:Double
    public let meanMomentumResidualY:Double
    public let kineticBefore:Double
    public let viscousLossPower:Double
    public let donorLossPower:Double
    public let divergenceTransportPower:Double
    public let sourcePower:Double
    public let explicitTimeInjection:Double
    public let energyDefect:Double
}
