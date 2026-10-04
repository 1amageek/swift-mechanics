public struct ContactDerivativeWork: Sendable {
    public let budget: ContactBudget
    public private(set) var operations: Int = 0
    public private(set) var peakScalarStorage: Int = 0
    public init(budget: ContactBudget) { self.budget=budget }
    public mutating func consume(operations count: Int, scalarStorage: Int, records: Int) throws(ContactDerivativeError) {
        guard !Task.isCancelled else { throw .cancelled }
        try absorb(operations:count,scalarStorage:scalarStorage,records:records)
    }
    internal mutating func absorb(operations count: Int, scalarStorage: Int, records: Int) throws(ContactDerivativeError) {
        let (next,overflow)=operations.addingReportingOverflow(count)
        guard count >= 0, scalarStorage >= 0, records >= 0, !overflow else { throw .invalidInput }
        guard next <= budget.operations else { throw .law(.resourceLimit(resource:.operations,limit:budget.operations)) }
        guard scalarStorage <= budget.scalarStorage else { throw .law(.resourceLimit(resource:.scalarStorage,limit:budget.scalarStorage)) }
        guard records <= budget.records else { throw .law(.resourceLimit(resource:.records,limit:budget.records)) }
        operations=next; peakScalarStorage=max(peakScalarStorage,scalarStorage)
    }
}
