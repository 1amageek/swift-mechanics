public struct LinearEstimatorPolicy: Sendable {
    public let maximumStateCount: Int
    public let maximumInputCount: Int
    public let maximumObservationCount: Int
    public let maximumMetadataBytes: Int
    public let maximumContinuationBytes: Int
    public let maximumCoefficientMagnitude: Double
    public let covarianceTolerance: Double
    public let rankThreshold: Double
    public let solveTolerance: LinearTolerance<Double>
    public let isCancelled: @Sendable () -> Bool
    public init(maximumStateCount: Int, maximumInputCount: Int, maximumObservationCount: Int,
                maximumMetadataBytes: Int, maximumContinuationBytes: Int, maximumCoefficientMagnitude: Double,
                covarianceTolerance: Double, rankThreshold: Double, solveTolerance: LinearTolerance<Double>,
                isCancelled: @escaping @Sendable () -> Bool = { false }) {
        self.maximumStateCount = maximumStateCount; self.maximumInputCount = maximumInputCount
        self.maximumObservationCount = maximumObservationCount; self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumContinuationBytes = maximumContinuationBytes; self.maximumCoefficientMagnitude = maximumCoefficientMagnitude
        self.covarianceTolerance = covarianceTolerance; self.rankThreshold = rankThreshold
        self.solveTolerance = solveTolerance; self.isCancelled = isCancelled
    }
}
