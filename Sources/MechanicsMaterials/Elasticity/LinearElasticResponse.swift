/// Infinitesimal Cauchy stress in Pa; energy density in J/m³.
public struct LinearElasticResponse: Sendable {
    public let stress: SymmetricTensor
    public let energyDensity: Double
}
