import MechanicsCore

/// Stress in Pa and stored energy density in J/m³ of reference volume.
public struct FiniteStressResponse: Sendable {
    public let greenStrain: SymmetricTensor
    public let secondPiolaStress: SymmetricTensor
    public let firstPiolaStress: Matrix3
    public let cauchyStress: Matrix3
    public let energyDensity: Double
}
