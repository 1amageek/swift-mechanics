public struct CollisionBudget: Equatable, Sendable {
    public let scalarStorage: Int
    public let operations: Int
    public let iterations: Int
    public let records: Int

    public init(scalarStorage: Int, operations: Int, iterations: Int, records: Int) throws(CollisionError) {
        guard scalarStorage >= 0, operations >= 0, iterations >= 0, records >= 0 else { throw .invalidPolicy }
        self.scalarStorage = scalarStorage; self.operations = operations
        self.iterations = iterations; self.records = records
    }
}
