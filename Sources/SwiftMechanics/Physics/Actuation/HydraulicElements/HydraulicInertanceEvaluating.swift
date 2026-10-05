public protocol HydraulicInertanceEvaluating: Sendable {
    func evaluate(volumeFlow: Double, flowAcceleration: Double, work: inout ActuationWork)
        throws(ActuationError) -> HydraulicElementResponse
}
