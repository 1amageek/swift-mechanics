internal final class ConstrainedSleepSource: Sendable {
    let accepted:RuntimeAcceptedState
    let history:ConstrainedSleepEventHistory
    init(accepted:RuntimeAcceptedState,history:ConstrainedSleepEventHistory) { self.accepted=accepted;self.history=history }
}
