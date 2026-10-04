public struct HybridEvolutionPolicy: Equatable, Sendable {
    public let maximumEvents: Int
    public let maximumQueries: Int
    public let maximumRootIterations: Int
    public let maximumCatalogEvents: Int
    public let maximumContinuationBytes: Int
    public let timeTolerance: Double
    public let minimumEventSpacing: Double
    public init(maximumEvents: Int, maximumQueries: Int, maximumRootIterations: Int, maximumCatalogEvents: Int,
                maximumContinuationBytes: Int, timeTolerance: Double, minimumEventSpacing: Double) throws(HybridError) {
        guard maximumEvents >= 0, maximumQueries > 0, maximumRootIterations > 0, maximumCatalogEvents > 0,
              maximumContinuationBytes > 0, timeTolerance.isFinite, timeTolerance > 0,
              minimumEventSpacing.isFinite, minimumEventSpacing > timeTolerance else { throw .invalidInput }
        self.maximumEvents=maximumEvents; self.maximumQueries=maximumQueries; self.maximumRootIterations=maximumRootIterations
        self.maximumCatalogEvents=maximumCatalogEvents; self.maximumContinuationBytes=maximumContinuationBytes
        self.timeTolerance=timeTolerance; self.minimumEventSpacing=minimumEventSpacing
    }
}
