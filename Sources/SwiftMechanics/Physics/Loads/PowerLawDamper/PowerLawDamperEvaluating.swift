public protocol PowerLawDamperEvaluating: Sendable {
    func evaluate(law: PowerLawDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
