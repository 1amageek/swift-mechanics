public struct OptimizationCertificate: Sendable {
    public let point: [Double]
    public let objective: Double
    public let equalityMultipliers: [Double], inequalityMultipliers: [Double], lowerMultipliers: [Double], upperMultipliers: [Double]
    public let primalResidual: Double, dualResidual: Double, stationarityResidual: Double, complementarityResidual: Double
    public let primalThreshold: Double, dualThreshold: Double, stationarityThreshold: Double, complementarityThreshold: Double
    public var threshold: Double { max(max(primalThreshold,dualThreshold),max(stationarityThreshold,complementarityThreshold)) }
    internal init(point: [Double], objective: Double, equality: [Double], inequality: [Double], lower: [Double], upper: [Double],
        primal: Double, dual: Double, stationarity: Double, complementarity: Double, primalThreshold: Double, dualThreshold: Double, stationarityThreshold: Double, complementarityThreshold: Double) {
        self.point=point; self.objective=objective; equalityMultipliers=equality; inequalityMultipliers=inequality; lowerMultipliers=lower; upperMultipliers=upper
        primalResidual=primal; dualResidual=dual; stationarityResidual=stationarity; complementarityResidual=complementarity; self.primalThreshold=primalThreshold; self.dualThreshold=dualThreshold; self.stationarityThreshold=stationarityThreshold; self.complementarityThreshold=complementarityThreshold
    }
}
