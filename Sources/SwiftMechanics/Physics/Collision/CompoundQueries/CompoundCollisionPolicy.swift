public struct CompoundCollisionPolicy: Sendable {
    public let maximumChildren: Int
    public let maximumMetadataBytes: Int

    public init(maximumChildren: Int, maximumMetadataBytes: Int) throws(CompoundCollisionError) {
        guard maximumChildren > 0, maximumMetadataBytes >= 0 else { throw .collision(.invalidPolicy) }
        self.maximumChildren = maximumChildren
        self.maximumMetadataBytes = maximumMetadataBytes
    }
}
