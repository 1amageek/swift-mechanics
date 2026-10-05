public struct LinearUnboundedCertificate: Sendable {
    public let feasiblePoint: [Double]
    public let physicalFeasiblePoint: [Double]
    public let direction: [Double]
    public let physicalDirection: [Double]
    public let objectiveSlope: Double
    public let physicalObjectiveSlope: Double
    public let baseObjective: Double
    public let maximumNormalizedPrimalResidual: Double
    internal init(feasiblePoint: [Double], physicalFeasiblePoint: [Double], direction: [Double], physicalDirection: [Double],
                  objectiveSlope: Double, physicalObjectiveSlope: Double, baseObjective: Double, maximumNormalizedPrimalResidual: Double) {
        self.feasiblePoint = feasiblePoint; self.physicalFeasiblePoint = physicalFeasiblePoint
        self.direction = direction; self.physicalDirection = physicalDirection
        self.objectiveSlope = objectiveSlope; self.physicalObjectiveSlope = physicalObjectiveSlope
        self.baseObjective = baseObjective; self.maximumNormalizedPrimalResidual = maximumNormalizedPrimalResidual
    }
}
