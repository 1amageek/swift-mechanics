public struct ThermoelasticLaw: Equatable, Sendable {
    public let elasticity: IsotropicElasticity, strainDomain: StrainDomain
    public let expansionCoefficient: Double, referenceTemperature: Double, minimumTemperature: Double, maximumTemperature: Double
    public init(elasticity: IsotropicElasticity, strainDomain: StrainDomain, expansionCoefficient: Double,
                referenceTemperature: Double, minimumTemperature: Double, maximumTemperature: Double) throws(MaterialError) {
        guard expansionCoefficient.isFinite, referenceTemperature.isFinite, minimumTemperature.isFinite,
              maximumTemperature.isFinite, minimumTemperature > 0, maximumTemperature > minimumTemperature,
              referenceTemperature >= minimumTemperature, referenceTemperature <= maximumTemperature else {
            throw .invalidParameter(name: "ThermoelasticLaw")
        }
        self.elasticity = elasticity; self.strainDomain = strainDomain; self.expansionCoefficient = expansionCoefficient
        self.referenceTemperature = referenceTemperature; self.minimumTemperature = minimumTemperature
        self.maximumTemperature = maximumTemperature
    }
}
