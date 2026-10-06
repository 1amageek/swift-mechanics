public protocol PolytropicGasEvaluating: Sendable {
    func evaluate(law: PolytropicGasLaw, stroke: Double, work: inout ActuationWork) throws(ActuationError) -> PolytropicGasResponse
}
