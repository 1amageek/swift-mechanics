public struct ExternalCommandPolicy: Equatable, Sendable {
    public let maximumPackets: Int
    public let maximumBatch: Int
    public let maximumMetadataBytes: Int
    public let maximumAllocationBytes: Int
    public let maximumWork: Int
    public init(maximumPackets: Int, maximumBatch: Int, maximumMetadataBytes: Int,
                maximumAllocationBytes: Int, maximumWork: Int) throws(ExternalCommandError) {
        guard maximumPackets >= 0, maximumBatch >= 0, maximumMetadataBytes >= 0,
              maximumAllocationBytes >= 0, maximumWork >= 0 else { throw .invalidPolicy }
        self.maximumPackets = maximumPackets; self.maximumBatch = maximumBatch
        self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumAllocationBytes = maximumAllocationBytes; self.maximumWork = maximumWork
    }
}
