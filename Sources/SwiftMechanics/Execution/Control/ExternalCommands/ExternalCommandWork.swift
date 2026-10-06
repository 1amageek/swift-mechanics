public struct ExternalCommandWork: Sendable {
    public let policy: ExternalCommandPolicy
    public private(set) var operations = 0
    public private(set) var allocationBytes = 0
    public private(set) var metadataBytes = 0
    public init(policy: ExternalCommandPolicy) { self.policy = policy }
    public mutating func charge(_ count: Int) throws(ExternalCommandError) {
        guard !Task.isCancelled else { throw .cancelled }
        let next = try Self.sum(operations, count)
        guard next <= policy.maximumWork else { throw .capacity(resource: "work", limit: policy.maximumWork) }
        operations = next
    }
    public mutating func allocate(_ count: Int) throws(ExternalCommandError) {
        try charge(0)
        let next = try Self.sum(allocationBytes, count)
        guard next <= policy.maximumAllocationBytes else {
            throw .capacity(resource: "allocationBytes", limit: policy.maximumAllocationBytes)
        }
        allocationBytes = next
    }
    public mutating func metadata(_ value: String) throws(ExternalCommandError) {
        for _ in value.utf8 {
            try charge(1)
            let total = try Self.sum(metadataBytes, 1)
            guard total <= policy.maximumMetadataBytes else {
                throw .capacity(resource: "metadataBytes", limit: policy.maximumMetadataBytes)
            }
            metadataBytes = total
        }
    }
    public static func sum(_ a: Int, _ b: Int) throws(ExternalCommandError) -> Int {
        let (result, overflow) = a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !overflow else { throw .integerOverflow }; return result
    }
    public static func product(_ a: Int, _ b: Int) throws(ExternalCommandError) -> Int {
        let (result, overflow) = a.multipliedReportingOverflow(by: b)
        guard a >= 0, b >= 0, !overflow else { throw .integerOverflow }; return result
    }
}
