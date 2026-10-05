public protocol RegularizedYieldDamperEvaluating: Sendable {
    func evaluate(law: RegularizedYieldDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
