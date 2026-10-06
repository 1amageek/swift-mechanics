public protocol FiniteExtensionSpringEvaluating: Sendable {
    func evaluate(law: FiniteExtensionSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
