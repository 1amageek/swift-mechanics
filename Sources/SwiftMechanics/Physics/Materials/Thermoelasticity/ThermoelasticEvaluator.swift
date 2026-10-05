public struct ThermoelasticEvaluator: ThermoelasticEvaluating {
    public init() {}
    public func evaluate(law: ThermoelasticLaw, totalStrain: SymmetricTensor, temperature: Double,
                         strainRate: SymmetricTensor, temperatureRate: Double) throws(MaterialError) -> ThermoelasticResponse {
        guard temperature.isFinite, temperatureRate.isFinite else { throw .invalidParameter(name: "thermalSample") }
        guard temperature >= law.minimumTemperature else {
            throw .outsideDomain(measure: "temperature", value: temperature, limit: law.minimumTemperature)
        }
        guard temperature <= law.maximumTemperature else {
            throw .outsideDomain(measure: "temperature", value: temperature, limit: law.maximumTemperature)
        }
        try law.strainDomain.validate(strain: totalStrain)
        let expansion = try finite(law.expansionCoefficient * (temperature - law.referenceTemperature))
        let elastic = try totalStrain.subtracting(.isotropic(expansion))
        let response = try law.elasticity.evaluate(strain: elastic, domain: law.strainDomain)
        let thermalDerivative = try SymmetricTensor.isotropic(finite(-3 * (law.elasticity.bulkModulus * law.expansionCoefficient)))
        let mechanicalPower = try response.stress.contracted(with: strainRate)
        let thermalPower = try finite(-law.expansionCoefficient * response.stress.trace() * temperatureRate)
        return ThermoelasticResponse(elasticStrain: elastic, stress: response.stress,
            stressTemperatureDerivative: thermalDerivative, freeEnergyDensity: response.energyDensity,
            mechanicalPowerDensity: mechanicalPower, thermalPowerDensity: thermalPower,
            freeEnergyRate: try finite(mechanicalPower + thermalPower))
    }
    public func tangent(law: ThermoelasticLaw, strainDirection: SymmetricTensor,
                        temperatureDirection: Double) throws(MaterialError) -> SymmetricTensor {
        guard temperatureDirection.isFinite else { throw .invalidParameter(name: "temperatureDirection") }
        let eigenstrainDirection = try SymmetricTensor.isotropic(finite(law.expansionCoefficient * temperatureDirection))
        return try law.elasticity.tangent(direction: strainDirection.subtracting(eigenstrainDirection))
    }
    private func finite(_ value: Double) throws(MaterialError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult(operation: "Thermoelasticity") }; return value
    }
}
