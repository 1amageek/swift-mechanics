public struct MaxwellLaw: Equatable, Sendable {
    public let modulus: Double, viscosity: Double, maximumStress: Double, maximumStrainRate: Double
    public init(modulus: Double, viscosity: Double, maximumStress: Double, maximumStrainRate: Double) throws(MaterialError) {
        guard modulus.isFinite, viscosity.isFinite, maximumStress.isFinite, maximumStrainRate.isFinite,
              modulus > 0, viscosity > 0, maximumStress > 0, maximumStrainRate > 0,
              (modulus / viscosity).isFinite, modulus / viscosity > 0 else { throw .invalidParameter(name: "MaxwellLaw") }
        self.modulus = modulus; self.viscosity = viscosity
        self.maximumStress = maximumStress; self.maximumStrainRate = maximumStrainRate
    }
}
