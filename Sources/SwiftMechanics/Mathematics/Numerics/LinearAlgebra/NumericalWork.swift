public struct NumericalWork: Equatable, Sendable {
    public let budget: NumericalBudget
    public private(set) var operations: Int = 0
    public private(set) var iterations: Int = 0
    public private(set) var peakScalarStorage: Int = 0
    public init(budget: NumericalBudget) { self.budget = budget }
    public mutating func requireStorage(_ count: Int) throws(NumericalError) {
        guard count >= 0, count <= budget.scalarStorage else { throw .resourceLimit(resource: .scalarStorage, limit: budget.scalarStorage) }
        peakScalarStorage = max(peakScalarStorage, count)
    }
    public mutating func chargeOperations(_ count: Int) throws(NumericalError) {
        let (next, overflow) = operations.addingReportingOverflow(count)
        guard count >= 0, !overflow, next <= budget.arithmeticOperations else {
            throw .resourceLimit(resource: .arithmeticOperations, limit: budget.arithmeticOperations)
        }
        operations = next
    }
    public mutating func advanceIteration() throws(NumericalError) {
        guard !Task.isCancelled else { throw .cancelled }
        guard iterations < budget.iterations else { throw .resourceLimit(resource: .iterations, limit: budget.iterations) }
        iterations += 1
    }
    public func remainingBudget(reservedStorage: Int) throws(NumericalError) -> NumericalBudget {
        guard reservedStorage >= 0, reservedStorage <= budget.scalarStorage else { throw .resourceLimit(resource: .scalarStorage, limit: budget.scalarStorage) }
        return try NumericalBudget(scalarStorage: budget.scalarStorage-reservedStorage,
            arithmeticOperations: budget.arithmeticOperations-operations, iterations: budget.iterations-iterations)
    }
    public mutating func absorb(_ nested: NumericalWork, reservedStorage: Int) throws(NumericalError) {
        try requireStorage(try Self.sum(reservedStorage, nested.peakScalarStorage))
        try chargeOperations(nested.operations)
        let (next, overflow) = iterations.addingReportingOverflow(nested.iterations)
        guard !overflow, next <= budget.iterations else { throw .resourceLimit(resource: .iterations, limit: budget.iterations) }
        iterations = next
    }
    public static func product(_ left: Int, _ right: Int) throws(NumericalError) -> Int {
        let (value, overflow) = left.multipliedReportingOverflow(by: right)
        guard left >= 0, right >= 0, !overflow else { throw .invalidDimensions }
        return value
    }
    public static func sum(_ left: Int, _ right: Int) throws(NumericalError) -> Int {
        let (value, overflow) = left.addingReportingOverflow(right)
        guard left >= 0, right >= 0, !overflow else { throw .invalidDimensions }
        return value
    }
}
