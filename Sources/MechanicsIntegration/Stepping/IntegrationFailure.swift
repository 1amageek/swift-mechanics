import MechanicsRuntime

public struct IntegrationFailure: Error, Sendable {
    public let cause: RuntimeFailure
    public let lastAccepted: RuntimeAcceptedState
    public let work: IntegrationWorkReport
    public let acceptedSteps: Int
    public let rejectedTrials: Int
    internal init(cause: RuntimeFailure, accepted: RuntimeAcceptedState, work: IntegrationWorkReport, steps: Int, rejects: Int) {
        self.cause = cause; lastAccepted = accepted; self.work = work; acceptedSteps = steps; rejectedTrials = rejects
    }
}
