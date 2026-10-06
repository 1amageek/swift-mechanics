public struct ForceObservation: Sendable {
    public let state: KinematicState
    public let appliedForceNewtons: Double
    public let forceStandardDeviationNewtons: Double
    public init(state: KinematicState, appliedForceNewtons: Double, forceStandardDeviationNewtons: Double) {
        self.state=state; self.appliedForceNewtons=appliedForceNewtons
        self.forceStandardDeviationNewtons=forceStandardDeviationNewtons
    }
}
