public struct ThermoelasticResponse: Sendable {
    public let elasticStrain: SymmetricTensor, stress: SymmetricTensor, stressTemperatureDerivative: SymmetricTensor
    /// Elastic free energy per unit reference volume, in J/m^3.
    public let freeEnergyDensity: Double
    /// Per-unit-volume mechanical and prescribed-temperature contributions, in W/m^3.
    public let mechanicalPowerDensity: Double, thermalPowerDensity: Double, freeEnergyRate: Double
}
