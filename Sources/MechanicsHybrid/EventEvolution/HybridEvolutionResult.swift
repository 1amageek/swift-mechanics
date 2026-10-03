import MechanicsRuntime

public struct HybridEvolutionResult: Sendable {
    public let accepted: RuntimeAcceptedState
    public let impacts: [NormalImpulseResult]
    public let work: HybridEvolutionWork
    internal init(accepted: RuntimeAcceptedState, impacts: [NormalImpulseResult], work: HybridEvolutionWork) {
        self.accepted=accepted; self.impacts=impacts; self.work=work
    }
}
