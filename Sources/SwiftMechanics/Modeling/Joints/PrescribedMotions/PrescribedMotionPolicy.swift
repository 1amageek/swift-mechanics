public struct PrescribedMotionPolicy: Sendable {
    public let maximumSamples:Int
    public let maximumIdentifierBytes:Int
    public let maximumMetadataBytes:Int
    public let isCancelled:@Sendable () -> Bool
    public init(maximumSamples:Int,maximumIdentifierBytes:Int,maximumMetadataBytes:Int,
                isCancelled:@escaping @Sendable () -> Bool = { false }) throws(PrescribedMotionError) {
        guard maximumSamples > 0,maximumIdentifierBytes > 0,maximumMetadataBytes > 0 else { throw .invalidInput }
        self.maximumSamples=maximumSamples;self.maximumIdentifierBytes=maximumIdentifierBytes
        self.maximumMetadataBytes=maximumMetadataBytes;self.isCancelled=isCancelled
    }
}
