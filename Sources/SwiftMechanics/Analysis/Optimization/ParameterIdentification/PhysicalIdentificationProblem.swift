public struct PhysicalIdentificationProblem: Sendable {
    public let source: PrismaticIdentificationSource
    public let observations: [ForceObservation]
    public let metadata: OptimizationMetadata
    public let lowerBounds: [Double]
    public let upperBounds: [Double]
    public init(source: PrismaticIdentificationSource, observations: [ForceObservation], metadata: OptimizationMetadata,
                lowerBounds: [Double], upperBounds: [Double]) {
        self.source=source; self.observations=observations; self.metadata=metadata
        self.lowerBounds=lowerBounds; self.upperBounds=upperBounds
    }
}
