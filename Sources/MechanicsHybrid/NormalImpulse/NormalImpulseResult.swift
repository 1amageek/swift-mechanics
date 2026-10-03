public struct NormalImpulseResult: Sendable {
    public let timeSeconds: Double
    public let eventIDs: [UInt64]
    /// World normal impulses in N s, with positive separating sign.
    public let normalImpulses: [Double]
    public let velocity: [Double]
    public let separatingSpeedsBefore: [Double]
    public let separatingSpeedsAfter: [Double]
    public let kineticEnergyBefore: Double
    public let kineticEnergyAfter: Double
    public let predictedEnergyLoss: Double
    public let normalizedMomentumResidual: Double
    public let lawResidual: Double
    public let energyResidual: Double
    internal init(time: Double, ids: [UInt64], impulses: [Double], velocity: [Double], before: [Double], after: [Double],
                  energyBefore: Double, energyAfter: Double, loss: Double, momentumResidual: Double, lawResidual: Double, energyResidual: Double) {
        timeSeconds=time; eventIDs=ids; normalImpulses=impulses; self.velocity=velocity
        separatingSpeedsBefore=before; separatingSpeedsAfter=after; kineticEnergyBefore=energyBefore; kineticEnergyAfter=energyAfter
        predictedEnergyLoss=loss; normalizedMomentumResidual=momentumResidual; self.lawResidual=lawResidual; self.energyResidual=energyResidual
    }
}
