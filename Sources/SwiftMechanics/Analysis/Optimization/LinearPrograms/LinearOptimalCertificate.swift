public struct LinearOptimalCertificate: Sendable {
    public let point: [Double]
    public let physicalPoint: [Double]
    public let objective: Double
    public let physicalObjective: Double
    public let multipliers: [LinearRowMultiplier]
    public let maximumNormalizedKKTResidual: Double
    public let primalDualGap: Double
    internal init(point: [Double], physicalPoint: [Double], objective: Double, physicalObjective: Double,
                  multipliers: [LinearRowMultiplier], maximumNormalizedKKTResidual: Double, primalDualGap: Double) {
        self.point = point; self.physicalPoint = physicalPoint; self.objective = objective; self.physicalObjective = physicalObjective
        self.multipliers = multipliers; self.maximumNormalizedKKTResidual = maximumNormalizedKKTResidual; self.primalDualGap = primalDualGap
    }
}
