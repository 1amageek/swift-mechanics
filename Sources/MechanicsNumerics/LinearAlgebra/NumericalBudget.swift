public struct NumericalBudget: Equatable, Sendable {
    public let scalarStorage: Int
    public let arithmeticOperations: Int
    public let iterations: Int
    public init(scalarStorage: Int, arithmeticOperations: Int, iterations: Int) throws(NumericalError) {
        guard scalarStorage >= 0, arithmeticOperations >= 0, iterations >= 0 else { throw .invalidPolicy }
        self.scalarStorage = scalarStorage; self.arithmeticOperations = arithmeticOperations; self.iterations = iterations
    }
}
