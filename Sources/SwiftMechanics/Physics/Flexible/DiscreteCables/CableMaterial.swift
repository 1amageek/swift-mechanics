public struct CableMaterial: Equatable, Sendable {
    public let identifier: EntityID
    public let source: SourceProvenance
    public let elasticity: IsotropicElasticity
    public let referenceDensity: Double
    public let area: Double
    public let secondMoment: Double
    public let massDampingRate: Double
    public let maximumAbsoluteAxialStrain: Double

    public init(identifier: EntityID, source: SourceProvenance, elasticity: IsotropicElasticity,
                referenceDensity: Double, area: Double, secondMoment: Double,
                massDampingRate: Double, maximumAbsoluteAxialStrain: Double) throws(CableError) {
        guard identifier.kind == .material, referenceDensity.isFinite, referenceDensity > 0,
              area.isFinite, area > 0, secondMoment.isFinite, secondMoment >= 0,
              massDampingRate.isFinite, massDampingRate >= 0,
              maximumAbsoluteAxialStrain.isFinite, maximumAbsoluteAxialStrain > 0 else { throw .invalidInput }
        self.identifier = identifier; self.source = source; self.elasticity = elasticity
        self.referenceDensity = referenceDensity; self.area = area; self.secondMoment = secondMoment
        self.massDampingRate = massDampingRate; self.maximumAbsoluteAxialStrain = maximumAbsoluteAxialStrain
    }
}
