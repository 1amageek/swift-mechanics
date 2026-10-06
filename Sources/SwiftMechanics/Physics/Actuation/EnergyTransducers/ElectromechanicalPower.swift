public struct ElectromechanicalPower: Equatable, Sendable {
    public let driveEffort: Double
    public let sourcePower: Double
    public let fieldPower: Double
    public let mechanicalPower: Double
    public let storagePower: Double
    public let physicalLoss: Double
    public let balanceResidual: Double
}
