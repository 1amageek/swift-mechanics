public protocol StribeckFrictionEvaluating: Sendable {
    func evaluate(law: StribeckFrictionLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
