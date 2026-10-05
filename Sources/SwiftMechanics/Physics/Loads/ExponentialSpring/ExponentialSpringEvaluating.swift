public protocol ExponentialSpringEvaluating: Sendable {
    func evaluate(law: ExponentialSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse
}
