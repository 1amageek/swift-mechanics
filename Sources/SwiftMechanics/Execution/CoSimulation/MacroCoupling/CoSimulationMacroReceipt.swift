public struct CoSimulationMacroReceipt: Sendable {
    public let boundary: CoSimulationBoundary
    public let firstStep: ControlStepResult
    public let secondStep: ControlStepResult
    public let firstHeldForceNewtons: Double
    public let exchangedWorkJoules: Double
    public let fixedDisturbanceWorkJoules: Double
    public let springEnergyChangeJoules: Double
    /// Continuous comparator damping energy along the actual trajectory; not measured held-port loss.
    public let continuousDampingOracleJoules: Double
    /// Original held-force discretization defect, not physical dissipation.
    public let energyDefectJoules: Double
    public let startPowerWatts: Double
    public let endPowerWatts: Double
    public let meanPowerWatts: Double
    internal init(boundary: CoSimulationBoundary, first: ControlStepResult, second: ControlStepResult,
                  force: Double, work: Double, disturbance: Double, spring: Double, damping: Double,
                  defect: Double, startPower: Double, endPower: Double, meanPower: Double) {
        self.boundary=boundary; firstStep=first; secondStep=second; firstHeldForceNewtons=force
        exchangedWorkJoules=work; fixedDisturbanceWorkJoules=disturbance; springEnergyChangeJoules=spring
        continuousDampingOracleJoules=damping; energyDefectJoules=defect; startPowerWatts=startPower
        endPowerWatts=endPower; meanPowerWatts=meanPower
    }
}
