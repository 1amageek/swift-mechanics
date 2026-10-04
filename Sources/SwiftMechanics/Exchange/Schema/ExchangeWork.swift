public struct ExchangeWork: Sendable {
    public let policy:ExchangePolicy
    public private(set) var operations=0
    public private(set) var allocationBytes=0
    public init(policy:ExchangePolicy) { self.policy=policy }
    public func checkCancellation() throws(ExchangeError) { guard !Task.isCancelled else { throw .cancelled } }
    public mutating func charge(_ count:Int) throws(ExchangeError) {
        try checkCancellation()
        let next=try Self.sum(operations,count)
        guard next <= policy.maximumOperations else { throw .resourceLimit(resource:.operations,limit:policy.maximumOperations) }; operations=next
    }
    public mutating func allocate(_ bytes:Int) throws(ExchangeError) {
        try checkCancellation()
        let next=try Self.sum(allocationBytes,bytes)
        guard next <= policy.maximumAllocationBytes else { throw .resourceLimit(resource:.allocationBytes,limit:policy.maximumAllocationBytes) }; allocationBytes=next
    }
    public static func sum(_ a:Int,_ b:Int) throws(ExchangeError) -> Int {
        let (v,o)=a.addingReportingOverflow(b); guard a >= 0,b >= 0,!o else { throw .arithmeticOverflow }; return v
    }
    public static func product(_ a:Int,_ b:Int) throws(ExchangeError) -> Int {
        let (v,o)=a.multipliedReportingOverflow(by:b); guard a >= 0,b >= 0,!o else { throw .arithmeticOverflow }; return v
    }
}
