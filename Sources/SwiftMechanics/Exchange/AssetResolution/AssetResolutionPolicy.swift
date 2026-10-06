public struct AssetResolutionPolicy: Sendable {
    public let maximumRoots: Int
    public let maximumReferences: Int
    public let maximumEdges: Int
    public let maximumDepth: Int
    public let maximumStringBytes: Int
    public let maximumMetadataBytes: Int
    public let maximumAssetBytes: Int
    public let maximumTotalBytes: Int
    public let maximumStorageBytes: Int
    public let maximumOperations: Int
    public let assetFormats: [String]
    public init(maximumRoots: Int, maximumReferences: Int, maximumEdges: Int, maximumDepth: Int,
                maximumStringBytes: Int, maximumMetadataBytes: Int, maximumAssetBytes: Int,
                maximumTotalBytes: Int, maximumStorageBytes: Int, maximumOperations: Int,
                assetFormats: [String]) throws(AssetResolutionFailure) {
        guard maximumRoots >= 0, maximumReferences >= 0, maximumEdges >= 0, maximumDepth >= 0,
              maximumStringBytes >= 0, maximumMetadataBytes >= 0, maximumAssetBytes >= 0,
              maximumTotalBytes >= 0, maximumStorageBytes >= 0, maximumOperations >= 0,
              assetFormats.count <= maximumReferences else { throw AssetResolutionFailure(.invalidPolicy) }
        self.maximumRoots = maximumRoots; self.maximumReferences = maximumReferences; self.maximumEdges = maximumEdges
        self.maximumDepth = maximumDepth; self.maximumStringBytes = maximumStringBytes; self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumAssetBytes = maximumAssetBytes; self.maximumTotalBytes = maximumTotalBytes
        self.maximumStorageBytes = maximumStorageBytes; self.maximumOperations = maximumOperations; self.assetFormats = assetFormats
    }
}
