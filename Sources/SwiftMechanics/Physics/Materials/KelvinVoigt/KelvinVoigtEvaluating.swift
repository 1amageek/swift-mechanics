public protocol KelvinVoigtEvaluating: Sendable {
    func evaluate(law: KelvinVoigtLaw, strain: SymmetricTensor, strainRate: SymmetricTensor) throws(MaterialError) -> KelvinVoigtResponse
    func tangent(law: KelvinVoigtLaw, strainDirection: SymmetricTensor, rateDirection: SymmetricTensor) throws(MaterialError) -> SymmetricTensor
}
