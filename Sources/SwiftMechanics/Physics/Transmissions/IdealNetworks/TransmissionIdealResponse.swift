public struct TransmissionIdealResponse: Sendable {
    public let generalizedEfforts: [Double]
    public let ports: [TransmissionPortEffort]
    public let originalPhaseResidual: Double
    public let originalSpeedResidual: Double
    public let totalPower: Double
    public let powerResidual: Double
}
