public struct CoSimulationStatus: Sendable {
    public let busy: Bool
    public let closed: Bool
    public let terminalFailure: CoSimulationFailure?
    /// During an operation the irreversible reservations are published when that operation finishes.
    public let completedOperationWork: CoSimulationWorkLedger
    internal init(busy: Bool, closed: Bool, failure: CoSimulationFailure?, work: CoSimulationWorkLedger) {
        self.busy=busy; self.closed=closed; terminalFailure=failure; completedOperationWork=work
    }
}
