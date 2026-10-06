public struct TransmissionPowerResponse: Equatable, Sendable {
    public let inputEffort: Double
    public let outputEffort: Double
    public let inputPower: Double
    public let outputPower: Double
    public let balanceResidual: Double
}
