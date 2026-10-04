public struct IsotropicElasticity: Equatable, Sendable, LinearElasticResponding {
    public let bulkModulus: Double
    public let shearModulus: Double
    public let lameLambda: Double

    public init(bulkModulus: Double, shearModulus: Double) throws(MaterialError) {
        guard bulkModulus.isFinite, bulkModulus > 0 else { throw .invalidParameter(name: "bulkModulus") }
        guard shearModulus.isFinite, shearModulus > 0 else { throw .invalidParameter(name: "shearModulus") }
        self.bulkModulus = bulkModulus
        self.shearModulus = shearModulus
        lameLambda = try materialFinite(bulkModulus - (2 / 3.0) * shearModulus, operation: "lameLambda")
        _ = try materialFinite(3 * shearModulus, operation: "elasticModulusScale")
    }

    public func tangent(direction: SymmetricTensor) throws(MaterialError) -> SymmetricTensor {
        let hydrostatic = try materialFinite(bulkModulus * (try direction.trace()), operation: "elasticPressure")
        return try direction.deviator().scaled(by: 2 * shearModulus).adding(.isotropic(hydrostatic))
    }

    public func evaluate(strain: SymmetricTensor, domain: StrainDomain) throws(MaterialError) -> LinearElasticResponse {
        try domain.validate(strain: strain)
        return LinearElasticResponse(stress: try tangent(direction: strain), energyDensity: try energy(strain: strain))
    }

    internal func energy(strain: SymmetricTensor) throws(MaterialError) -> Double {
        let trace = try strain.trace(), dev = try strain.deviator()
        return try materialFinite(0.5 * bulkModulus * trace * trace + shearModulus * (try dev.contracted(with: dev)), operation: "elasticEnergy")
    }
}
