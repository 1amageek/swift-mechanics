public struct CollisionWork: Sendable {
    public let budget: CollisionBudget
    public private(set) var operations = 0
    public private(set) var iterations = 0
    public private(set) var peakScalarStorage = 0

    public init(budget: CollisionBudget) { self.budget = budget }

    public func checkCancellation() throws(CollisionError) {
        guard !Task.isCancelled else { throw .cancelled }
    }

    public mutating func charge(_ count: Int) throws(CollisionError) {
        try checkCancellation()
        let next = try Self.sum(operations, count)
        guard next <= budget.operations else { throw .resourceLimit(resource: .operations, limit: budget.operations) }
        operations = next
    }

    public mutating func requireStorage(_ count: Int) throws(CollisionError) {
        try checkCancellation()
        guard count >= 0, count <= budget.scalarStorage else { throw .resourceLimit(resource: .scalarStorage, limit: budget.scalarStorage) }
        peakScalarStorage = max(peakScalarStorage, count)
    }

    public func requireRecords(_ count: Int) throws(CollisionError) {
        try checkCancellation()
        guard count >= 0, count <= budget.records else { throw .resourceLimit(resource: .records, limit: budget.records) }
    }

    public mutating func advanceIteration() throws(CollisionError) {
        try checkCancellation()
        guard iterations < budget.iterations else { throw .resourceLimit(resource: .iterations, limit: budget.iterations) }
        iterations += 1
    }

    public static func product(_ a: Int, _ b: Int) throws(CollisionError) -> Int {
        let (value, overflow) = a.multipliedReportingOverflow(by: b)
        guard a >= 0, b >= 0, !overflow else { throw .arithmeticFailure }
        return value
    }

    public static func sum(_ a: Int, _ b: Int) throws(CollisionError) -> Int {
        let (value, overflow) = a.addingReportingOverflow(b)
        guard a >= 0, b >= 0, !overflow else { throw .arithmeticFailure }
        return value
    }
}
