import MechanicsModel
import MechanicsMaterials
public struct FlexibleMaterial: Sendable {
    public let identifier: EntityID
    public let source: SourceProvenance
    public let law: PolynomialHyperelasticity
    public let referenceDensity: Double
    public let massDampingRate: Double
    public init(identifier: EntityID, source: SourceProvenance, law: PolynomialHyperelasticity, referenceDensity: Double, massDampingRate: Double) throws(FlexibleError) {
        guard identifier.kind == .material else { throw .invalidIdentity }
        guard referenceDensity.isFinite, referenceDensity > 0, massDampingRate.isFinite, massDampingRate >= 0 else { throw .invalidParameter }
        self.identifier = identifier; self.source = source; self.law = law; self.referenceDensity = referenceDensity; self.massDampingRate = massDampingRate
    }
}
