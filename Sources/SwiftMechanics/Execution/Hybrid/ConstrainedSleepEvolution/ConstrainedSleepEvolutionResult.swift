public struct ConstrainedSleepEvolutionResult: Sendable {
    public let accepted:RuntimeAcceptedState
    public let impact:ConstrainedNormalImpulseResult?
    public let work:ConstrainedSleepEvolutionWork
    internal init(accepted:RuntimeAcceptedState,impact:ConstrainedNormalImpulseResult?,work:ConstrainedSleepEvolutionWork) { self.accepted=accepted;self.impact=impact;self.work=work }
}
