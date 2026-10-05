internal final class SensorDecodedState: Sendable {
    let state: SensorPipelineState
    let evidence: RuntimeValidationEvidence
    init(state: SensorPipelineState, evidence: RuntimeValidationEvidence) { self.state = state; self.evidence = evidence }
}
