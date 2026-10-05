public protocol TabulatedDamperEvaluating: Sendable {
    func evaluate(law: TabulatedDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> TabulatedDamperResponse
}
