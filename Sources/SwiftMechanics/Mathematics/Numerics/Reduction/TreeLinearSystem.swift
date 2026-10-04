public struct TreeLinearSystem<Scalar: NumericalScalar>: Sendable {
    public let parents: [Int]
    public let diagonal: [Scalar]
    public let edges: [Scalar]
    public var count: Int { diagonal.count }
    public init(parents: [Int], diagonal: [Scalar], edges: [Scalar]) throws(NumericalError) {
        guard !diagonal.isEmpty, parents.count == diagonal.count, edges.count == diagonal.count else { throw .invalidDimensions }
        guard parents[0] == -1, edges[0] == 0 else { throw .invalidTree(node: 0) }
        guard diagonal.allSatisfy({ $0.isFinite }), edges.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        for i in 1..<diagonal.count { guard parents[i] >= 0, parents[i] < i else { throw .invalidTree(node: i) } }
        self.parents = parents; self.diagonal = diagonal; self.edges = edges
    }
    public func applying(_ vector: [Scalar], budget: NumericalBudget) throws(NumericalError) -> [Scalar] {
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.product(4, count))
        return try multiply(vector, work: &work)
    }
    func multiply(_ vector: [Scalar], work: inout NumericalWork) throws(NumericalError) -> [Scalar] {
        guard vector.count == count else { throw .invalidDimensions }
        guard vector.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        try work.chargeOperations(try NumericalWork.product(5, count))
        var result = [Scalar](repeating: 0, count: count)
        for i in 0..<count { guard !Task.isCancelled else { throw .cancelled }; result[i] = diagonal[i] * vector[i] }
        for i in 1..<count {
            let p = parents[i]
            result[i] += edges[i] * vector[p]; result[p] += edges[i] * vector[i]
        }
        guard result.allSatisfy({ $0.isFinite }) else { throw .nonFiniteResult }
        return result
    }
}
