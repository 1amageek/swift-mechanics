public struct SensorPipelineBounds: Sendable {
    public let maximumChannels: Int
    public let maximumMetadataBytes: Int
    public let maximumTicksPerStep: Int
    public let maximumTick: UInt64
    public let maximumDraws: UInt64
    public let maximumPendingRows: Int
    public let maximumReadyRows: Int
    public let maximumBatchRows: Int
    public let maximumContributorBytes: Int
    public let maximumDelaySeconds: Double
    public let rawBudget: NumericalBudget
    public init(maximumChannels: Int, maximumMetadataBytes: Int, maximumTicksPerStep: Int, maximumTick: UInt64,
                maximumDraws: UInt64, maximumPendingRows: Int, maximumReadyRows: Int, maximumBatchRows: Int,
                maximumContributorBytes: Int, maximumDelaySeconds: Double, rawBudget: NumericalBudget) throws(SensorPipelineFailure) {
        guard maximumChannels > 0, maximumMetadataBytes >= 0, maximumTicksPerStep > 0,
              maximumTick <= 9_007_199_254_740_991, maximumDraws > 0, maximumPendingRows >= 0,
              maximumReadyRows >= 0, maximumBatchRows >= 0, maximumContributorBytes > 0,
              maximumDelaySeconds.isFinite, maximumDelaySeconds >= 0 else { throw .invalidDefinition }
        self.maximumChannels = maximumChannels; self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumTicksPerStep = maximumTicksPerStep; self.maximumTick = maximumTick; self.maximumDraws = maximumDraws
        self.maximumPendingRows = maximumPendingRows; self.maximumReadyRows = maximumReadyRows
        self.maximumBatchRows = maximumBatchRows; self.maximumContributorBytes = maximumContributorBytes
        self.maximumDelaySeconds = maximumDelaySeconds; self.rawBudget = rawBudget
    }
}
