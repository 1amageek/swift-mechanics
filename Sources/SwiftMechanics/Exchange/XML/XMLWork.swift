public struct XMLWork: Sendable {
    public let policy: XMLPolicy
    public private(set) var operations = 0
    public private(set) var storageBytes = 0
    public private(set) var decodedBytes = 0
    public init(policy: XMLPolicy) { self.policy = policy }
    public func checkCancellation(at location: XMLLocation = XMLLocation()) throws(XMLFailure) {
        guard !Task.isCancelled else { throw XMLFailure(.cancelled, at: location) }
    }
    internal mutating func charge(_ count: Int, at location: XMLLocation) throws(XMLFailure) {
        try checkCancellation(at: location)
        operations = try Self.increment(operations, count, limit: policy.maximumOperations, resource: .operations, at: location)
    }
    internal mutating func allocate(_ count: Int, at location: XMLLocation) throws(XMLFailure) {
        try checkCancellation(at: location)
        storageBytes = try Self.increment(storageBytes, count, limit: policy.maximumStorageBytes, resource: .storageBytes, at: location)
    }
    internal mutating func payload(_ count: Int, at location: XMLLocation) throws(XMLFailure) {
        try inspectPayload(count, at: location)
        try allocate(count, at: location)
    }
    internal mutating func inspectPayload(_ count: Int, at location: XMLLocation) throws(XMLFailure) {
        try checkCancellation(at: location)
        decodedBytes = try Self.increment(decodedBytes, count, limit: policy.maximumDecodedBytes, resource: .decodedBytes, at: location)
    }
    internal static func increment(_ value: Int, _ count: Int, limit: Int, resource: XMLResource, at location: XMLLocation) throws(XMLFailure) -> Int {
        let (next, overflow) = value.addingReportingOverflow(count)
        guard value >= 0, count >= 0, !overflow else { throw XMLFailure(.arithmeticOverflow, at: location) }
        guard next <= limit else { throw XMLFailure(.limit(resource, limit), at: location) }
        return next
    }
}
