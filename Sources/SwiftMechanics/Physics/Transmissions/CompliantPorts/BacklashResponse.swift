public struct BacklashResponse: Sendable {
    public let phaseEffort: Double
    public let potentialEnergy: Double
    public let potentialRate: Double
    public let dissipativePower: Double
    public let mapped: MappedTransmissionPorts
    public let originalPowerResidual: Double
    public let trial: BacklashContinuation
}
