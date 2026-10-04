public struct DenseMatrix<Scalar: NumericalScalar>: LinearOperating, Sendable {
    public let rowCount: Int
    public let columnCount: Int
    let storage: [Scalar]
    public init(rows: Int, columns: Int, values: [Scalar]) throws(NumericalError) {
        guard rows > 0, columns > 0, try NumericalWork.product(rows, columns) == values.count else { throw .invalidDimensions }
        guard values.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        rowCount = rows; columnCount = columns; storage = values
    }
    public func coefficient(row: Int, column: Int) throws(NumericalError) -> Scalar {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount else { throw .invalidIndex }
        return storage[row * columnCount + column]
    }
    public func applying(_ vector: [Scalar], budget: NumericalBudget) throws(NumericalError) -> [Scalar] {
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.sum(storage.count, try NumericalWork.sum(vector.count, rowCount)))
        return try multiply(vector, work: &work)
    }
    func multiply(_ vector: [Scalar], work: inout NumericalWork) throws(NumericalError) -> [Scalar] {
        guard vector.count == columnCount else { throw .invalidDimensions }
        guard vector.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        try work.chargeOperations(try NumericalWork.product(2, storage.count))
        var result = [Scalar](repeating: 0, count: rowCount)
        for i in 0..<rowCount {
            guard !Task.isCancelled else { throw .cancelled }
            var value: Scalar = 0
            for j in 0..<columnCount { value += storage[i * columnCount + j] * vector[j] }
            guard value.isFinite else { throw .nonFiniteResult }
            result[i] = value
        }
        return result
    }
}
