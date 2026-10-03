import MechanicsCore

public struct EquationScaler<Scalar: NumericalScalar>: EquationScaling, Sendable {
    public init() {}
    public func scale(_ system: DimensionalLinearSystem<Scalar>, rowReferences: [SIReferenceQuantity<Scalar>],
                      columnReferences: [SIReferenceQuantity<Scalar>], budget: NumericalBudget) throws(NumericalError) -> ScaledLinearSystem<Scalar> {
        let n = system.matrix.rowCount, m = system.matrix.columnCount
        guard rowReferences.count == n, columnReferences.count == m else { throw .invalidDimensions }
        for i in 0..<n {
            guard rowReferences[i].magnitude > 0 else { throw .invalidPolicy }
            guard rowReferences[i].dimension == system.equationDimensions[i] else { throw .dimensionMismatch }
        }
        for j in 0..<m {
            guard columnReferences[j].magnitude > 0 else { throw .invalidPolicy }
            guard columnReferences[j].dimension == system.unknownDimensions[j] else { throw .dimensionMismatch }
        }
        var work = NumericalWork(budget: budget)
        let entries = try NumericalWork.product(n, m)
        try work.requireStorage(try NumericalWork.sum(try NumericalWork.product(2, entries), try NumericalWork.product(3, try NumericalWork.sum(n, m))))
        try work.chargeOperations(try NumericalWork.sum(try NumericalWork.product(2, entries), n))
        var values = [Scalar](repeating: 0, count: entries), rhs = [Scalar](repeating: 0, count: n)
        for i in 0..<n {
            guard !Task.isCancelled else { throw .cancelled }
            rhs[i] = system.rightHandSide[i] / rowReferences[i].magnitude
            guard rhs[i].isFinite else { throw .nonFiniteResult }
            for j in 0..<m {
                // Apply the ratio first to avoid overflow for mixed physical scales.
                let ratio = columnReferences[j].magnitude / rowReferences[i].magnitude
                values[i*m+j] = (try system.matrix.coefficient(row: i, column: j)) * ratio
                guard ratio.isFinite, ratio > 0, values[i*m+j].isFinite else { throw .nonFiniteResult }
            }
        }
        return ScaledLinearSystem(original: system, matrix: try DenseMatrix(rows: n, columns: m, values: values),
                                  rightHandSide: rhs, rowReferences: rowReferences, columnReferences: columnReferences, work: work)
    }
}
