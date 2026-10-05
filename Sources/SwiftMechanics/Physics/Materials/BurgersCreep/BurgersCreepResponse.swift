public struct BurgersCreepResponse: Sendable {
    public let state: BurgersCreepState
    public let totalStrain: Double, endpointCreepRate: Double
    public let elasticStrainJump: Double, heldStressStrainIncrement: Double
    public let storedEnergy: Double, storageChange: Double
    public let stressJumpWork: Double, heldStressWork: Double
    public let dissipatedEnergy: Double, energyResidual: Double
}
