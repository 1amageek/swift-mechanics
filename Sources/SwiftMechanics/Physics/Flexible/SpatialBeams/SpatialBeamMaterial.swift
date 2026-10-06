/// Homogeneous isotropic material. E/G/rho have SI units Pa/Pa/kg per cubic metre.
public struct SpatialBeamMaterial: Equatable, Sendable {
    public let identity: EntityID
    public let source: SourceProvenance
    public let youngModulus: Double
    public let shearModulus: Double
    public let density: Double
    public let elasticity: IsotropicElasticity

    public init(identity: EntityID, source: SourceProvenance, youngModulus: Double,
                shearModulus: Double, density: Double) throws(SpatialBeamError) {
        guard identity.kind == .material else { throw .invalidInput(parameter: "materialIdentity") }
        for value in [youngModulus, shearModulus, density] {
            guard value.isFinite, value > 0 else { throw .invalidInput(parameter: "materialCoefficients") }
        }
        let ratio = youngModulus / shearModulus
        guard ratio.isFinite, ratio > 0, ratio < 3 else { throw .invalidInput(parameter: "isotropicModulusRatio") }
        let bulk = youngModulus / (3 * (3 - ratio))
        do throws(MaterialError) {
            elasticity = try IsotropicElasticity(bulkModulus: bulk, shearModulus: shearModulus)
        } catch { throw .material(error) }
        self.identity = identity; self.source = source
        self.youngModulus = youngModulus; self.shearModulus = shearModulus; self.density = density
    }
}
