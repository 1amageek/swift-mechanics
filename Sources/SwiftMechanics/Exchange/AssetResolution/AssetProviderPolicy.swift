public struct AssetProviderPolicy: Equatable, Sendable {
    public let maximumInventoryRecords: Int
    public let maximumReads: Int
    public let maximumBytesRead: Int
    public let maximumOperations: Int
    public init(maximumInventoryRecords: Int, maximumReads: Int, maximumBytesRead: Int,
                maximumOperations: Int) throws(AssetProviderFailure) {
        guard maximumInventoryRecords >= 0, maximumReads >= 0, maximumBytesRead >= 0, maximumOperations >= 0 else { throw .invalidLimits }
        self.maximumInventoryRecords = maximumInventoryRecords; self.maximumReads = maximumReads
        self.maximumBytesRead = maximumBytesRead; self.maximumOperations = maximumOperations
    }
}
