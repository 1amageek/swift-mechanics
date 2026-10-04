
public protocol PlasticResponding: Sendable {
    func initialHistory() -> PlasticHistory
    func evaluate(greenStrain: SymmetricTensor, acceptedHistory: PlasticHistory) throws(MaterialError) -> PlasticTrial
    func tangent(greenStrain: SymmetricTensor, direction: SymmetricTensor, acceptedHistory: PlasticHistory) throws(MaterialError) -> SymmetricTensor
    func evaluate(deformationGradient: Matrix3, acceptedHistory: PlasticHistory) throws(MaterialError) -> PlasticFiniteTrial
    func tangent(deformationGradient: Matrix3, direction: Matrix3, acceptedHistory: PlasticHistory) throws(MaterialError) -> FiniteStressDirectionalResponse
}
