public struct ExternalCommandStream: Equatable, Sendable {
    public let binding: ActuatorBinding
    public let producer: String
    public let configurationRevision: UInt64
    public let mode: DriveMode
    public let clock: ControlClock
    public let delaySeconds: Double
    public let maximumAgeSeconds: Double
    public let maximumGapSeconds: Double
    public let interpolation: ExternalCommandInterpolation
    public let siUnit: UnitDefinition
    internal init(binding: ActuatorBinding, producer: String, configurationRevision: UInt64,
                  mode: DriveMode, clock: ControlClock, delaySeconds: Double,
                  maximumAgeSeconds: Double, maximumGapSeconds: Double,
                  interpolation: ExternalCommandInterpolation, siUnit: UnitDefinition) {
        self.binding = binding; self.producer = producer; self.configurationRevision = configurationRevision
        self.mode = mode; self.clock = clock; self.delaySeconds = delaySeconds
        self.maximumAgeSeconds = maximumAgeSeconds; self.maximumGapSeconds = maximumGapSeconds
        self.interpolation = interpolation; self.siUnit = siUnit
    }
}
