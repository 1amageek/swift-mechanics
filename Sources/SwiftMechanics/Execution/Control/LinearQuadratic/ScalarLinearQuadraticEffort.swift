public struct ScalarLinearQuadraticEffort: Sendable {
    public let port: ScalarControlPort
    public let sampleTimeSeconds: Double
    public let samplePeriodSeconds: Double
    public let nominalEffortNewtons: Double
    public let unconstrainedEffortNewtons: Double
    public let command: DriveCommand
    public let saturated: Bool
}
