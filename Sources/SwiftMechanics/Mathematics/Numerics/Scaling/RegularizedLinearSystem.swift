
public struct RegularizedLinearSystem<Scalar: NumericalScalar>: Sendable {
    public let original: DimensionalLinearSystem<Scalar>
    public let matrix: DenseMatrix<Scalar>
    public let diagonalPerturbation: [SIReferenceQuantity<Scalar>]
    public let allowedMagnitude: [SIReferenceQuantity<Scalar>]
    public let maximumNormalizedPerturbation: Scalar
    public let work: NumericalWork
    public func effect(of solution: [Scalar], tolerance: LinearTolerance<Scalar>, budget: NumericalBudget) throws(NumericalError) -> RegularizationEffect<Scalar> {
        guard solution.count == diagonalPerturbation.count else { throw .invalidDimensions }
        guard original.equationDimensions.allSatisfy({ $0 == original.equationDimensions[0] }) else { throw .dimensionMismatch }
        var work = NumericalWork(budget: budget)
        let entries = try NumericalWork.product(matrix.rowCount, matrix.columnCount)
        let reserved = try NumericalWork.sum(entries, try NumericalWork.product(5, solution.count))
        try work.requireStorage(try NumericalWork.sum(reserved, try NumericalWork.sum(entries, try NumericalWork.product(2, solution.count))))
        try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(4, entries), try NumericalWork.product(5, solution.count)))
        let multiplicationBudget = try NumericalBudget(scalarStorage: budget.scalarStorage-reserved,
            arithmeticOperations: NumericalWork.product(2, entries), iterations: 0)
        let product = try original.matrix.applying(solution, budget: multiplicationBudget)
        let changed = try matrix.applying(solution, budget: multiplicationBudget)
        var effect: [SIReferenceQuantity<Scalar>] = []
        effect.reserveCapacity(solution.count)
        for i in solution.indices {
            let value = diagonalPerturbation[i].magnitude * solution[i]
            guard value.isFinite else { throw .nonFiniteResult }
            effect.append(try SIReferenceQuantity(magnitude: value, dimension: original.equationDimensions[i]))
        }
        return RegularizationEffect(originalResidual: try ResidualEvidence.measure(product: product, rightHandSide: original.rightHandSide, tolerance: tolerance),
            perturbedResidual: try ResidualEvidence.measure(product: changed, rightHandSide: original.rightHandSide, tolerance: tolerance),
            modelEffect: effect, maximumNormalizedPerturbation: maximumNormalizedPerturbation)
    }
}
