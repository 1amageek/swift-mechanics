public struct DahlFrictionResponse: Equatable, Sendable {
    public let state: DahlFrictionState
    public let endpointForce: Double, meanForce: Double, storedEnergy: Double, storageChange: Double
    public let frictionWork: Double, dissipatedEnergy: Double, energyResidual: Double
}
