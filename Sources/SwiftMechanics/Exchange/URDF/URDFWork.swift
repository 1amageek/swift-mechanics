public struct URDFWork: Sendable {
    public let policy: URDFPolicy
    public private(set) var operations = 0
    public private(set) var storageBytes = 0
    public var xml: XMLWork
    public init(policy: URDFPolicy, xmlPolicy: XMLPolicy) { self.policy = policy; xml = XMLWork(policy: xmlPolicy) }

    internal mutating func charge(_ count: Int, at location: XMLLocation = XMLLocation()) throws(URDFFailure) {
        guard !Task.isCancelled else { throw URDFFailure(.cancelled, at: location) }
        operations = try increment(operations, count, limit: policy.maximumOperations, resource: "operations", at: location)
    }
    internal mutating func allocate(_ count: Int, stride: Int = 1, at location: XMLLocation = XMLLocation()) throws(URDFFailure) {
        try charge(1, at: location)
        let (bytes, overflow) = count.multipliedReportingOverflow(by: stride)
        guard count >= 0, stride >= 0, !overflow else { throw URDFFailure(.arithmeticOverflow, at: location) }
        storageBytes = try increment(storageBytes, bytes, limit: policy.maximumStorageBytes, resource: "storageBytes", at: location)
    }
    internal func limit(_ count: Int, _ maximum: Int, _ resource: String, at location: XMLLocation) throws(URDFFailure) {
        guard count <= maximum else { throw URDFFailure(.limit(resource, maximum), at: location) }
    }
    private func increment(_ current: Int, _ count: Int, limit: Int, resource: String,
                           at location: XMLLocation) throws(URDFFailure) -> Int {
        let (next, overflow) = current.addingReportingOverflow(count)
        guard count >= 0, !overflow else { throw URDFFailure(.arithmeticOverflow, at: location) }
        guard next <= limit else { throw URDFFailure(.limit(resource, limit), at: location) }
        return next
    }
}
