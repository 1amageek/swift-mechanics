public struct BurgersCreepLaw: Equatable, Sendable {
    public let maxwellModulus: Double, maxwellViscosity: Double, kelvinModulus: Double, kelvinViscosity: Double
    public let maximumStress: Double, maximumKelvinStrain: Double, maximumViscousStrain: Double
    public let kelvinDecay: Double
    public init(maxwellModulus: Double, maxwellViscosity: Double, kelvinModulus: Double, kelvinViscosity: Double,
                maximumStress: Double, maximumKelvinStrain: Double, maximumViscousStrain: Double) throws(MaterialError) {
        guard maxwellModulus.isFinite, maxwellModulus > 0, maxwellViscosity.isFinite, maxwellViscosity > 0,
              kelvinModulus.isFinite, kelvinModulus > 0, kelvinViscosity.isFinite, kelvinViscosity > 0,
              maximumStress.isFinite, maximumStress > 0, maximumKelvinStrain.isFinite, maximumKelvinStrain > 0,
              maximumViscousStrain.isFinite, maximumViscousStrain > 0 else { throw .invalidParameter(name: "burgersCreepLaw") }
        let decay=kelvinModulus/kelvinViscosity
        guard decay.isFinite, decay > 0, (maximumStress/maxwellModulus).isFinite,
              (maximumStress/kelvinModulus).isFinite else { throw .invalidParameter(name: "burgersCreepLaw") }
        self.maxwellModulus=maxwellModulus; self.maxwellViscosity=maxwellViscosity
        self.kelvinModulus=kelvinModulus; self.kelvinViscosity=kelvinViscosity
        self.maximumStress=maximumStress; self.maximumKelvinStrain=maximumKelvinStrain
        self.maximumViscousStrain=maximumViscousStrain; kelvinDecay=decay
    }
}
