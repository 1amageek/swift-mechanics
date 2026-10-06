internal struct CoSimulationState: Sendable {
    var busy=false
    var closed=false
    var terminalFailure: CoSimulationFailure?
    var boundary: CoSimulationBoundary
    var work: CoSimulationWorkLedger
    init(boundary: CoSimulationBoundary) { self.boundary=boundary; work=boundary.work }
}
