public struct ControlStepResult: Sendable {
    public let observation:ControlObservation
    public let integration:IntegrationAdvanceResult
    public let actuationWork:ActuationWork
    internal init(observation:ControlObservation,integration:IntegrationAdvanceResult,actuationWork:ActuationWork) {
        self.observation=observation;self.integration=integration;self.actuationWork=actuationWork
    }
}
