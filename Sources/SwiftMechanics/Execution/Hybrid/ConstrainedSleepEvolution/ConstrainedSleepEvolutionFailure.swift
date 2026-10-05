public struct ConstrainedSleepEvolutionFailure: Error, Sendable {
    public let cause:ConstrainedSleepEvolutionCause
    public let accepted:RuntimeAcceptedState
    public let work:ConstrainedSleepEvolutionWork
    internal init(cause:ConstrainedSleepEvolutionCause,accepted:RuntimeAcceptedState,work:ConstrainedSleepEvolutionWork) { self.cause=cause;self.accepted=accepted;self.work=work }
}
