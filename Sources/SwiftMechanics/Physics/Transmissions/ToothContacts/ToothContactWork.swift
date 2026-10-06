public struct ToothContactWork: Sendable {
    public let budget: NumericalBudget
    public let maximumSupplierCalls: Int
    public private(set) var operations: Int = 0
    public private(set) var iterations: Int = 0
    public private(set) var supplierCalls: Int = 0
    public private(set) var peakScalarStorage: Int = 0
    public init(budget: NumericalBudget, maximumSupplierCalls: Int) throws(ToothContactError) {
        guard maximumSupplierCalls >= 0 else { throw .invalidInput }
        self.budget=budget; self.maximumSupplierCalls=maximumSupplierCalls
    }
    internal mutating func charge(_ count: Int, storage: Int = 0, iterations countIterations: Int = 0) throws(ToothContactError) {
        let (op,ov)=operations.addingReportingOverflow(count), (it,iv)=iterations.addingReportingOverflow(countIterations)
        guard count >= 0, storage >= 0, countIterations >= 0, !ov, !iv,
              op <= budget.arithmeticOperations, it <= budget.iterations, storage <= budget.scalarStorage else { throw .capacityExceeded }
        operations=op; iterations=it; peakScalarStorage=max(peakScalarStorage,storage)
    }
    internal mutating func beginCall() throws(ToothContactError) {
        guard supplierCalls < maximumSupplierCalls else { throw .capacityExceeded }
        try charge(1); supplierCalls += 1
    }
}
