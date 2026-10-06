public protocol ThermoelasticEvaluating: Sendable {
    func evaluate(law: ThermoelasticLaw, totalStrain: SymmetricTensor, temperature: Double,
                  strainRate: SymmetricTensor, temperatureRate: Double) throws(MaterialError) -> ThermoelasticResponse
    func tangent(law: ThermoelasticLaw, strainDirection: SymmetricTensor,
                 temperatureDirection: Double) throws(MaterialError) -> SymmetricTensor
}
