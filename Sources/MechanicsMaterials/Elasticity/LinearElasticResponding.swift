public protocol LinearElasticResponding: Sendable {
    func evaluate(strain: SymmetricTensor, domain: StrainDomain) throws(MaterialError) -> LinearElasticResponse
    func tangent(direction: SymmetricTensor) throws(MaterialError) -> SymmetricTensor
}
