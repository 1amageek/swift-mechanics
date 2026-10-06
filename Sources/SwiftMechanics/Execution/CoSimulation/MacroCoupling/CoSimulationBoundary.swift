public struct CoSimulationBoundary: Sendable {
    public let first: ControlObservation
    public let second: ControlObservation
    public let work: CoSimulationWorkLedger
    public let accumulatedAbsoluteEnergyDefectJoules: Double
    public var tick: UInt64 { first.controller.tick }
    public var timeSeconds: Double { first.accepted.checkpoint.physical.time }
    internal init(first: ControlObservation, second: ControlObservation, work: CoSimulationWorkLedger, defect: Double) {
        self.first=first; self.second=second; self.work=work; accumulatedAbsoluteEnergyDefectJoules=defect
    }
}
