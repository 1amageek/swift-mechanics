public struct ExternalDriveStep: Sendable {
    public let selection: ExternalCommandSelection
    public let actuatorResponse: ActuatorResponse
    public let intervalEndTimeSeconds: Double
    internal init(selection: ExternalCommandSelection, actuatorResponse: ActuatorResponse,
                  intervalEndTimeSeconds: Double) {
        self.selection = selection; self.actuatorResponse = actuatorResponse
        self.intervalEndTimeSeconds = intervalEndTimeSeconds
    }
}
