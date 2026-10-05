/// Exclusive caller-owned semantic ledger; supplier ledgers remain separate.
public struct MJCFWork: Sendable {
    public let policy: MJCFPolicy
    public private(set) var operations = 0
    /// Cumulative logical payload reservation; allocator overhead is target-profile authority.
    public private(set) var allocationBytes = 0
    public private(set) var compilerCalls = 0
    public init(policy: MJCFPolicy) { self.policy = policy }
    public mutating func charge(_ count: Int) throws(MJCFError) {
        guard !Task.isCancelled, !policy.isCancelled() else { throw .cancelled }
        let next = try MJCFArithmetic.sum(operations, count)
        guard next <= policy.maximumOperations else { throw .workExhausted }; operations = next
    }
    public mutating func allocate(_ bytes: Int) throws(MJCFError) {
        try charge(0)
        let next = try MJCFArithmetic.sum(allocationBytes, bytes)
        guard next <= policy.maximumStorageBytes else { throw .capacityExceeded }; allocationBytes = next
    }
    internal mutating func compilerCall() throws(MJCFError) { try charge(1); compilerCalls = try MJCFArithmetic.sum(compilerCalls, 1) }
    internal mutating func text(_ string: String) throws(MJCFError) {
        var count = 0
        for _ in string.utf8 { try charge(1); count = try MJCFArithmetic.sum(count, 1); guard count <= policy.maximumIdentifierBytes else { throw .capacityExceeded } }
        try allocate(count)
    }
}
