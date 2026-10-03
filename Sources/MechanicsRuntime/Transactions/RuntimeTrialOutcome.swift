public struct RuntimeTrialOutcome: Sendable {
    public let decision: RuntimeTrialDecision
    public let accepted: RuntimeAcceptedState
    public let admittedWorkUnits: Int
    internal init(decision: RuntimeTrialDecision, accepted: RuntimeAcceptedState, admittedWorkUnits: Int) {
        self.decision = decision; self.accepted = accepted; self.admittedWorkUnits = admittedWorkUnits
    }
}
