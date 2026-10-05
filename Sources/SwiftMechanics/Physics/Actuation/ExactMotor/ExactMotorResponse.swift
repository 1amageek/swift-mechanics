public struct ExactMotorResponse: Equatable, Sendable {
    public let state: ExactMotorState
    public let meanCurrent: Double, meanTorque: Double, magneticEnergy: Double, storageChange: Double
    public let sourceWork: Double, shaftWork: Double, copperLoss: Double, viscousLoss: Double, energyResidual: Double
}
