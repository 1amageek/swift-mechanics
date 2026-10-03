public struct ScaledLinearSystem<Scalar: NumericalScalar>: Sendable {
    public let original: DimensionalLinearSystem<Scalar>
    public let matrix: DenseMatrix<Scalar>
    public let rightHandSide: [Scalar]
    public let rowReferences: [SIReferenceQuantity<Scalar>]
    public let columnReferences: [SIReferenceQuantity<Scalar>]
    public let work: NumericalWork
    public func recover(_ scaledSolution: [Scalar], budget: NumericalBudget) throws(NumericalError) -> [Scalar] {
        guard scaledSolution.count == columnReferences.count else { throw .invalidDimensions }
        guard scaledSolution.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.product(3, scaledSolution.count))
        try work.chargeOperations(scaledSolution.count)
        var result = [Scalar](repeating: 0, count: scaledSolution.count)
        for i in scaledSolution.indices {
            result[i] = columnReferences[i].magnitude * scaledSolution[i]
            guard result[i].isFinite else { throw .nonFiniteResult }
        }
        return result
    }
}
