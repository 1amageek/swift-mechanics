public struct KelvinVoigtLaw: Equatable, Sendable {
    public let elasticity: IsotropicElasticity
    public let strainDomain: StrainDomain
    public let bulkViscosity: Double
    public let shearViscosity: Double
    public let maximumRateNorm: Double
    public init(elasticity: IsotropicElasticity, strainDomain: StrainDomain,
                bulkViscosity: Double, shearViscosity: Double, maximumRateNorm: Double) throws(MaterialError) {
        guard bulkViscosity.isFinite, bulkViscosity >= 0, shearViscosity.isFinite, shearViscosity >= 0,
              (2 * shearViscosity).isFinite, maximumRateNorm.isFinite, maximumRateNorm > 0 else {
            throw .invalidParameter(name: "kelvinVoigtLaw")
        }
        self.elasticity = elasticity; self.strainDomain = strainDomain
        self.bulkViscosity = bulkViscosity; self.shearViscosity = shearViscosity
        self.maximumRateNorm = maximumRateNorm
    }
}
