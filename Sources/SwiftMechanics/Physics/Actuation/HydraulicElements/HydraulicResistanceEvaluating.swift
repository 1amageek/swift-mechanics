public protocol HydraulicResistanceEvaluating: Sendable {
    func evaluate(pressureDifference: Double, work: inout ActuationWork)
        throws(ActuationError) -> HydraulicElementResponse
}
