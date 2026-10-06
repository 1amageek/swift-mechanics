public struct CADGeometryLimits: Sendable {
    public let maximumFeatures: Int
    public let maximumParameters: Int
    public let maximumOccurrences: Int
    public let maximumExpressionNodes: Int
    public let maximumExpressionDepth: Int
    public let maximumMetadataBytes: Int
    public let maximumTopologyRecords: Int
    public let maximumQueryResults: Int

    public init(maximumFeatures: Int, maximumParameters: Int, maximumOccurrences: Int,
                maximumExpressionNodes: Int, maximumExpressionDepth: Int,
                maximumMetadataBytes: Int, maximumTopologyRecords: Int,
                maximumQueryResults: Int) throws(CADAdapterError) {
        guard maximumFeatures >= 0, maximumParameters >= 0, maximumOccurrences >= 0,
              maximumExpressionNodes >= 0, maximumExpressionDepth >= 0,
              maximumMetadataBytes >= 0, maximumTopologyRecords >= 0,
              maximumQueryResults >= 0 else { throw .invalidInput }
        self.maximumFeatures = maximumFeatures
        self.maximumParameters = maximumParameters
        self.maximumOccurrences = maximumOccurrences
        self.maximumExpressionNodes = maximumExpressionNodes
        self.maximumExpressionDepth = maximumExpressionDepth
        self.maximumMetadataBytes = maximumMetadataBytes
        self.maximumTopologyRecords = maximumTopologyRecords
        self.maximumQueryResults = maximumQueryResults
    }
}
