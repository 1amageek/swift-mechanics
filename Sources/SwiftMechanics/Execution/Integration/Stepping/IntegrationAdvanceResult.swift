
public struct IntegrationAdvanceResult: Sendable {
    public let requestedTime: Double
    public let accepted: RuntimeAcceptedState
    public let acceptedSteps: Int
    public let rejectedTrials: Int
    public let work: IntegrationWorkReport
    public let lastNormalizedError: Double?
    public var reachedRequestedTime: Bool { accepted.checkpoint.physical.time == requestedTime }
    internal init(requested: Double, accepted: RuntimeAcceptedState, steps: Int, rejects: Int, work: IntegrationWorkReport, error: Double?) {
        requestedTime = requested; self.accepted = accepted; acceptedSteps = steps; rejectedTrials = rejects; self.work = work; lastNormalizedError = error
    }
}
