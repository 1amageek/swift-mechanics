public struct KelvinVoigtResponse: Sendable {
    public let elasticStress: SymmetricTensor
    public let viscousStress: SymmetricTensor
    public let stress: SymmetricTensor
    public let energyDensity: Double
    public let energyRate: Double
    public let dissipatedPowerDensity: Double
    public let stressPowerDensity: Double
    public let powerResidual: Double
}
