public struct MaxwellResponse: Equatable, Sendable {
    public let state: MaxwellState
    public let meanStress: Double, storedEnergy: Double, storageChange: Double
    public let inputWork: Double, dissipatedEnergy: Double, energyResidual: Double
}
