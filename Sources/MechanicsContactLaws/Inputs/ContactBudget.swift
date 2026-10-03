public struct ContactBudget: Sendable {
    public let operations: Int
    public let scalarStorage: Int
    public let records: Int
    public init(operations: Int, scalarStorage: Int, records: Int) throws(ContactLawError) {
        guard operations >= 0, scalarStorage >= 0, records >= 0 else { throw .invalidPolicy }
        self.operations=operations; self.scalarStorage=scalarStorage; self.records=records
    }
}
