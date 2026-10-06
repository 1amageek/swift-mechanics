public struct StandardLinearSolidResponse: Sendable {
    public let state: StandardLinearSolidState
    public let endpointStress: Double
    public let meanStress: Double
    public let storedEnergy: Double
    public let storageChange: Double
    public let inputWork: Double
    public let dissipatedEnergy: Double
    public let energyResidual: Double
}
