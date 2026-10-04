
public protocol HyperelasticResponding: Sendable {
    func evaluate(deformationGradient: Matrix3) throws(MaterialError) -> FiniteStressResponse
    func tangent(deformationGradient: Matrix3, direction: Matrix3) throws(MaterialError) -> FiniteStressDirectionalResponse
}
