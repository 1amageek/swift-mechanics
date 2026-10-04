public struct BeamAdmission: Sendable {
    public let maximumElements: Int
    public let maximumMetadataBytes: Int
    public let isCancelled: @Sendable () -> Bool
    public init(maximumElements: Int, maximumMetadataBytes: Int, isCancelled: @escaping @Sendable () -> Bool) throws(BeamError) {
        guard maximumElements > 0, maximumMetadataBytes >= 0 else { throw .invalidInput }
        self.maximumElements=maximumElements;self.maximumMetadataBytes=maximumMetadataBytes;self.isCancelled=isCancelled
    }
}
