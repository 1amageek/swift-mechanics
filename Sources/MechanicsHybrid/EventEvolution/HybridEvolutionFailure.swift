import MechanicsRuntime

public struct HybridEvolutionFailure: Error, Sendable {
    public let cause: HybridError
    public let lastAccepted: RuntimeAcceptedState
    public let work: HybridEvolutionWork
    internal init(cause: HybridError, accepted: RuntimeAcceptedState, work: HybridEvolutionWork) {
        self.cause=cause; lastAccepted=accepted; self.work=work
    }
}
