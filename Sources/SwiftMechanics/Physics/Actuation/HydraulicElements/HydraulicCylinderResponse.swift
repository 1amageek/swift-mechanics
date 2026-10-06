public struct HydraulicCylinderResponse: Equatable, Sendable {
    public let firstPressureRate: Double
    public let secondPressureRate: Double
    public let leakageFlow: Double
    public let force: Double
    public let sourcePower: Double
    public let mechanicalPower: Double
    public let storedEnergy: Double
    public let storagePower: Double
    public let dissipatedPower: Double
    public let balanceResidual: Double
}
