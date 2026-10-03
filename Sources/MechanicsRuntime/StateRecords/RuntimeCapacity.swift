public struct RuntimeCapacity: Equatable, Sendable {
    public let maximumPhysicalScalars: Int
    public let maximumContributors: Int
    public let maximumContributorBytes: Int
    public let maximumMetadataBytes: Int
    public let maximumCheckpointBytes: Int
    public let maximumValidationWork: Int
    public let maximumValidationScratchBytes: Int
    public let maximumObservationLeases: Int
    public let maximumBatchStates: Int
    public let maximumTransactions: UInt64
    public let maximumStepWorkUnits: Int
    public let maximumWorkBetweenSafePoints: Int
    public init(maximumPhysicalScalars: Int, maximumContributors: Int, maximumContributorBytes: Int,
                maximumMetadataBytes: Int, maximumCheckpointBytes: Int, maximumValidationWork: Int,
                maximumValidationScratchBytes: Int, maximumObservationLeases: Int, maximumBatchStates: Int,
                maximumTransactions: UInt64, maximumStepWorkUnits: Int, maximumWorkBetweenSafePoints: Int) throws(RuntimeFailure) {
        guard maximumPhysicalScalars >= 0, maximumContributors >= 0, maximumContributorBytes >= 0,
              maximumMetadataBytes >= 0, maximumCheckpointBytes >= 0, maximumValidationWork >= 0,
              maximumValidationScratchBytes >= 0, maximumObservationLeases >= 0, maximumBatchStates >= 0,
              maximumTransactions > 0, maximumStepWorkUnits >= 0, maximumWorkBetweenSafePoints > 0 else {
            throw RuntimeFailure(.invalidInput, message: "Runtime capacities must be nonnegative; transaction count and safe-point quantum positive.")
        }
        self.maximumPhysicalScalars = maximumPhysicalScalars; self.maximumContributors = maximumContributors
        self.maximumContributorBytes = maximumContributorBytes; self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumCheckpointBytes = maximumCheckpointBytes; self.maximumValidationWork = maximumValidationWork
        self.maximumValidationScratchBytes = maximumValidationScratchBytes; self.maximumObservationLeases = maximumObservationLeases
        self.maximumBatchStates = maximumBatchStates; self.maximumTransactions = maximumTransactions
        self.maximumStepWorkUnits = maximumStepWorkUnits; self.maximumWorkBetweenSafePoints = maximumWorkBetweenSafePoints
    }
}
