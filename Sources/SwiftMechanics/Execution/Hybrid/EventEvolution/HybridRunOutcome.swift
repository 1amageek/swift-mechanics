
internal final class HybridRunOutcome: Sendable {
    let accepted: RuntimeAcceptedState
    let impacts: [NormalImpulseResult]
    let work: HybridEvolutionWork
    init(accepted: RuntimeAcceptedState, impacts: [NormalImpulseResult], work: HybridEvolutionWork) {
        self.accepted=accepted; self.impacts=impacts; self.work=work
    }
}
