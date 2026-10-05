public protocol SealedLiquidEvaluating: Sendable {
    func evaluate(law: SealedLiquidLaw, stroke: Double, work: inout ActuationWork) throws(ActuationError) -> SealedLiquidResponse
}
