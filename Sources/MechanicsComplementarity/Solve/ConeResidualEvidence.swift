public struct ConeResidualEvidence: Sendable {
    public let primalFeasibility: Double
    public let dualFeasibility: Double
    public let complementarity: Double
    public let optimality: Double
    public let tolerance: ConeTolerance

    public var isAccepted: Bool {
        primalFeasibility <= tolerance.primalThreshold && dualFeasibility <= tolerance.dualThreshold
            && complementarity <= tolerance.complementarityThreshold && optimality <= tolerance.optimalityThreshold
    }

    public var maximumResidual: Double {
        max(primalFeasibility, dualFeasibility, complementarity, optimality)
    }
}
