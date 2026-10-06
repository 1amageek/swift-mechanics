public struct LocalKKTProof: Sendable {
    public let primalResidual: Double, dualResidual: Double, stationarityResidual: Double, complementarityResidual: Double
    public let primalThreshold: Double, dualThreshold: Double, stationarityThreshold: Double, complementarityThreshold: Double
    public let activeRank: Int, tangentDimension: Int, nullspaceResidual: Double
    public let nullspaceBasis: [Double], reducedLagrangianHessian: [Double]
}
