public struct KelvinVoigtEvaluator: KelvinVoigtEvaluating {
    public init() {}
    public func evaluate(law: KelvinVoigtLaw, strain: SymmetricTensor, strainRate: SymmetricTensor) throws(MaterialError) -> KelvinVoigtResponse {
        let norm = try strainRate.norm()
        guard norm <= law.maximumRateNorm else {
            throw .outsideDomain(measure: "strainRateNorm", value: norm, limit: law.maximumRateNorm)
        }
        let elastic = try law.elasticity.evaluate(strain: strain, domain: law.strainDomain)
        let viscous = try viscousStress(law: law, rate: strainRate)
        let stress = try elastic.stress.adding(viscous)
        let trace = try strainRate.trace(), dev = try strainRate.deviator()
        let dissipation = try finite(law.bulkViscosity * trace * trace
            + 2 * law.shearViscosity * (try dev.contracted(with: dev)))
        let energyRate = try elastic.stress.contracted(with: strainRate)
        let power = try stress.contracted(with: strainRate)
        return KelvinVoigtResponse(elasticStress: elastic.stress, viscousStress: viscous, stress: stress,
            energyDensity: elastic.energyDensity, energyRate: energyRate, dissipatedPowerDensity: dissipation,
            stressPowerDensity: power, powerResidual: try finite(power - energyRate - dissipation))
    }
    public func tangent(law: KelvinVoigtLaw, strainDirection: SymmetricTensor, rateDirection: SymmetricTensor) throws(MaterialError) -> SymmetricTensor {
        try law.elasticity.tangent(direction: strainDirection).adding(viscousStress(law: law, rate: rateDirection))
    }
    private func viscousStress(law: KelvinVoigtLaw, rate: SymmetricTensor) throws(MaterialError) -> SymmetricTensor {
        try rate.deviator().scaled(by: 2 * law.shearViscosity)
            .adding(.isotropic(finite(law.bulkViscosity * (try rate.trace()))))
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "KelvinVoigt") }
        return value
    }
}
