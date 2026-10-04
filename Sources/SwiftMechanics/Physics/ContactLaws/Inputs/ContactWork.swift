public struct ContactWork: Sendable {
    public let budget: ContactBudget
    public private(set) var operations: Int = 0
    public private(set) var peakScalarStorage: Int = 0
    public init(budget: ContactBudget) { self.budget=budget }
    public func checkCancellation() throws(ContactLawError) {
        guard !Task.isCancelled else { throw .cancelled }
    }
    public mutating func consume(operations count: Int, scalarStorage: Int, records: Int) throws(ContactLawError) {
        try checkCancellation()
        guard scalarStorage <= budget.scalarStorage else { throw .resourceLimit(resource:.scalarStorage,limit:budget.scalarStorage) }
        guard records <= budget.records else { throw .resourceLimit(resource:.records,limit:budget.records) }
        let (next,overflow)=operations.addingReportingOverflow(count)
        guard count >= 0, scalarStorage >= 0, records >= 0, !overflow else { throw .arithmeticFailure }
        guard next <= budget.operations else { throw .resourceLimit(resource:.operations,limit:budget.operations) }
        operations=next; peakScalarStorage=max(peakScalarStorage,scalarStorage)
    }
}
