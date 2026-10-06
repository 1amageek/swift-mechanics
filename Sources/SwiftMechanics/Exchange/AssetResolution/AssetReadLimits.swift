public struct AssetReadLimits: Sendable {
    public let maximumBytes: Int
    public let maximumDependencies: Int
    public let maximumStringBytes: Int
    public let maximumMetadataBytes: Int
    public init(maximumBytes: Int, maximumDependencies: Int, maximumStringBytes: Int,
                maximumMetadataBytes: Int) throws(AssetProviderFailure) {
        guard maximumBytes >= 0, maximumDependencies >= 0, maximumStringBytes >= 0, maximumMetadataBytes >= 0 else { throw .invalidLimits }
        self.maximumBytes = maximumBytes; self.maximumDependencies = maximumDependencies
        self.maximumStringBytes = maximumStringBytes; self.maximumMetadataBytes = maximumMetadataBytes
    }
}
