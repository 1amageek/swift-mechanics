public protocol NeoHookeanEvaluating: Sendable {
    func evaluate(law: NeoHookeanLaw, deformationGradient: Matrix3) throws(MaterialError) -> NeoHookeanResponse
    func tangent(law: NeoHookeanLaw, deformationGradient: Matrix3, direction: Matrix3) throws(MaterialError) -> NeoHookeanDirectionalResponse
}
