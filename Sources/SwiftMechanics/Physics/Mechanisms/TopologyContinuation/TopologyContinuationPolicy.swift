public struct TopologyContinuationPolicy: Equatable, Sendable {
    public let maximumEvents: Int
    public let maximumBytes: Int
    public let maximumMetadataBytes: Int
    public let maximumWork: Int
    public init(maximumEvents:Int,maximumBytes:Int,maximumMetadataBytes:Int,maximumWork:Int) throws(TopologyReleaseFailure) {
        guard maximumEvents > 0, maximumBytes > 0, maximumMetadataBytes > 0, maximumWork > 0 else { throw .invalidInput }
        self.maximumEvents=maximumEvents; self.maximumBytes=maximumBytes; self.maximumMetadataBytes=maximumMetadataBytes; self.maximumWork=maximumWork
    }
}
