import MechanicsNumerics

public struct ConstraintVelocitySolution: Sendable {
    public let velocity: [Double]
    public let originalResidual: Double
    public let correctionNorm: Double
    public let introducedKineticEnergy: Double
    public let rank: ConstraintRankEvidence
    public let responseWork: NumericalWork
    public let linearWork: NumericalWork
    public init(velocity: [Double], originalResidual: Double, correctionNorm: Double, introducedKineticEnergy: Double,
                  rank: ConstraintRankEvidence, responseWork: NumericalWork, linearWork: NumericalWork) {
        self.velocity=velocity; self.originalResidual=originalResidual; self.correctionNorm=correctionNorm
        self.introducedKineticEnergy=introducedKineticEnergy; self.rank=rank; self.responseWork=responseWork; self.linearWork=linearWork
    }
}
