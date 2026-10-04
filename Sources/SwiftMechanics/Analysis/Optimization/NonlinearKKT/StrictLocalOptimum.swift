public struct StrictLocalOptimum: Sendable {
    public let metadata: OptimizationMetadata, point: [Double], objective: Double
    public let physicalPoint: [Double], physicalObjective: Double
    public let equalityMultipliers: [Double], inequalityMultipliers: [Double], lowerMultipliers: [Double], upperMultipliers: [Double]
    public let activeInequalities: [Int], proof: LocalKKTProof, work: NumericalWork
}
