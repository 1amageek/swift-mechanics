/// A conformer records only known consumed prefixes, including when read throws.
public struct AssetProviderWork: Sendable {
    public let policy: AssetProviderPolicy
    public private(set) var reads = 0
    public private(set) var bytesRead = 0
    public private(set) var operations = 0
    public init(policy: AssetProviderPolicy) { self.policy = policy }
    public var remainingBytes: Int { policy.maximumBytesRead - bytesRead }
    public mutating func beginRead() throws(AssetProviderFailure) {
        try charge(1)
        reads = try increment(reads, 1, maximum: policy.maximumReads, resource: .providerReads)
    }
    public mutating func consumeBytes(_ count: Int) throws(AssetProviderFailure) {
        try charge(count)
        bytesRead = try increment(bytesRead, count, maximum: policy.maximumBytesRead, resource: .providerBytes)
    }
    public mutating func charge(_ count: Int) throws(AssetProviderFailure) {
        try checkCancellation()
        operations = try increment(operations, count, maximum: policy.maximumOperations, resource: .providerOperations)
    }
    public func checkCancellation() throws(AssetProviderFailure) { guard !Task.isCancelled else { throw .cancelled } }
    private func increment(_ value: Int, _ count: Int, maximum: Int, resource: AssetResource) throws(AssetProviderFailure) -> Int {
        let (next, overflow) = value.addingReportingOverflow(count)
        guard count >= 0, !overflow else { throw .arithmeticOverflow }
        guard next <= maximum else { throw .limit(resource, maximum) }
        return next
    }
}
