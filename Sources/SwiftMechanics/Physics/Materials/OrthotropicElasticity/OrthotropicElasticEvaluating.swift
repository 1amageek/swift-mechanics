public protocol OrthotropicElasticEvaluating: Sendable {
    func evaluate(law: OrthotropicElasticLaw, strain: SymmetricTensor, domain: StrainDomain) throws(MaterialError) -> OrthotropicElasticResponse
    func tangent(law: OrthotropicElasticLaw, direction: SymmetricTensor) throws(MaterialError) -> SymmetricTensor
}
