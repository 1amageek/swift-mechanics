public struct CoSimulationOwnerPrefix: Sendable {
    public let participant: String
    /// Nil means the current prefix could not be acquired; a cached publication is never substituted.
    public let current: RuntimeAcceptedState?
    /// Most recent actual receipt known to this exclusive owner, even when current acquisition failed.
    public let lastKnown: RuntimeAcceptedState?
    public let restored: Bool
    internal init(participant: String, current: RuntimeAcceptedState?, lastKnown: RuntimeAcceptedState? = nil, restored: Bool) {
        self.participant=participant; self.current=current; self.lastKnown=lastKnown ?? current; self.restored=restored
    }
}
