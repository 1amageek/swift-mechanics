public protocol HydraulicComplianceEvaluating: Sendable {
    func evaluate(volumeDisplacement: Double, volumeFlow: Double, work: inout ActuationWork)
        throws(ActuationError) -> HydraulicElementResponse
}
