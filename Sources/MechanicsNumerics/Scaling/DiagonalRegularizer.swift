import MechanicsCore

public struct DiagonalRegularizer<Scalar: NumericalScalar>: EquationRegularizing, Sendable {
    public init() {}
    public func addingDiagonal(to system: DimensionalLinearSystem<Scalar>, perturbation: [SIReferenceQuantity<Scalar>],
                               allowedMagnitude: [SIReferenceQuantity<Scalar>], budget: NumericalBudget) throws(NumericalError) -> RegularizedLinearSystem<Scalar> {
        let n = system.matrix.rowCount
        guard system.matrix.columnCount == n, perturbation.count == n, allowedMagnitude.count == n else { throw .invalidDimensions }
        var fraction: Scalar = 0
        for i in 0..<n {
            let dimension = try system.coefficientDimension(row: i, column: i)
            guard perturbation[i].dimension == dimension, allowedMagnitude[i].dimension == dimension else { throw .dimensionMismatch }
            let delta = perturbation[i].magnitude, limit = allowedMagnitude[i].magnitude
            guard delta >= 0, limit > 0 else { throw .invalidPolicy }
            guard delta <= limit else { throw .perturbationExceeded(value: Double(delta), maximum: Double(limit)) }
            fraction = max(fraction, delta/limit)
        }
        var work = NumericalWork(budget: budget)
        let entries = try NumericalWork.product(n, n)
        try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(2, entries), try NumericalWork.product(4, n)))
        try work.chargeOperations(try NumericalWork.product(2, n))
        var values = [Scalar](repeating: 0, count: entries)
        for i in 0..<n {
            guard !Task.isCancelled else { throw .cancelled }
            for j in 0..<n { values[i*n+j] = try system.matrix.coefficient(row: i, column: j) }
            values[i*n+i] += perturbation[i].magnitude
            guard values[i*n+i].isFinite else { throw .nonFiniteResult }
        }
        return RegularizedLinearSystem(original: system, matrix: try DenseMatrix(rows: n, columns: n, values: values),
            diagonalPerturbation: perturbation, allowedMagnitude: allowedMagnitude,
            maximumNormalizedPerturbation: fraction, work: work)
    }
}
