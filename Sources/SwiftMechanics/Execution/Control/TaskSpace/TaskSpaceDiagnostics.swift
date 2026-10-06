public struct TaskSpaceDiagnostics: Sendable {
    public let taskRank: Int?
    public let damping: Double
    public let usesExactDynamicallyConsistentInverse: Bool
    public let primaryAcceleration: [Double]
    public let projectedSecondaryAcceleration: [Double]
    public let achievedTaskAcceleration: [Double]
    public let primaryTaskResidual: [Double]
    public let secondaryTaskLeak: [Double]
    public let taskResidual: [Double]
    public let regularizationDefect: [Double]
    public let secondaryRegularizationDefect: [Double]
    public let pointTaskDualForceNewtons: Vector3?
    public let generalizedDrivePowerWatts: Double
    public let taskDualVirtualPowerWatts: Double
    public let taskDualActualPowerWatts: Double
    public let taskDualPrescribedPowerWatts: Double
    public let virtualPowerResidualWatts: Double
    public let work: NumericalWork
}
