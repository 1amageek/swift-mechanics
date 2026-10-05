public protocol TabulatedSpringEvaluating: Sendable {
    func evaluate(law: TabulatedSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> TabulatedSpringResponse
}
