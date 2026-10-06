public struct AssetResolutionWork: Sendable {
    public let policy: AssetResolutionPolicy
    public private(set) var operations = 0
    public private(set) var storageBytes = 0
    public private(set) var metadataBytes = 0
    /// Bytes validated into local staging, not a claim that a catalog was published.
    public private(set) var validatedPayloadBytes = 0
    public var provider: AssetProviderWork
    public init(policy: AssetResolutionPolicy, providerPolicy: AssetProviderPolicy) {
        self.policy = policy; provider = AssetProviderWork(policy: providerPolicy)
    }
    public mutating func charge(_ count: Int, address: AssetAddress? = nil) throws(AssetResolutionFailure) {
        guard !Task.isCancelled else { throw AssetResolutionFailure(.cancelled, address: address) }
        operations = try increment(operations, count, maximum: policy.maximumOperations, resource: .operations, address: address)
    }
    internal mutating func allocate(_ count: Int, stride: Int = 1, address: AssetAddress? = nil) throws(AssetResolutionFailure) {
        try charge(1, address: address)
        let (bytes, overflow) = count.multipliedReportingOverflow(by: stride)
        guard count >= 0, stride >= 0, !overflow else { throw AssetResolutionFailure(.arithmeticOverflow, address: address) }
        storageBytes = try increment(storageBytes, bytes, maximum: policy.maximumStorageBytes, resource: .storageBytes, address: address)
    }
    internal mutating func text(_ text: String, address: AssetAddress? = nil) throws(AssetResolutionFailure) {
        try limit(text.utf8.count, maximum: policy.maximumStringBytes, resource: .stringBytes, address: address)
        try charge(text.utf8.count, address: address)
        metadataBytes = try increment(metadataBytes, text.utf8.count, maximum: policy.maximumMetadataBytes, resource: .metadataBytes, address: address)
    }
    internal mutating func validatedBytes(_ count: Int, address: AssetAddress) throws(AssetResolutionFailure) {
        try charge(1, address: address)
        validatedPayloadBytes = try increment(validatedPayloadBytes, count, maximum: policy.maximumTotalBytes, resource: .totalBytes, address: address)
    }
    internal func limit(_ count: Int, maximum: Int, resource: AssetResource, address: AssetAddress? = nil) throws(AssetResolutionFailure) {
        guard count >= 0 else { throw AssetResolutionFailure(.arithmeticOverflow, address: address) }
        guard count <= maximum else { throw AssetResolutionFailure(.limit(resource, maximum), address: address) }
    }
    internal static func sum(_ a: Int, _ b: Int, address: AssetAddress? = nil) throws(AssetResolutionFailure) -> Int {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !overflow else { throw AssetResolutionFailure(.arithmeticOverflow, address: address) }
        return value
    }
    private func increment(_ value: Int, _ count: Int, maximum: Int, resource: AssetResource, address: AssetAddress?) throws(AssetResolutionFailure) -> Int {
        let next = try Self.sum(value, count, address: address)
        guard next <= maximum else { throw AssetResolutionFailure(.limit(resource, maximum), address: address) }
        return next
    }
}
