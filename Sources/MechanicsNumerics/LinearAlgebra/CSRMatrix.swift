public struct CSRMatrix<Scalar: NumericalScalar>: LinearOperating, Sendable {
    public let rowCount: Int
    public let columnCount: Int
    public let rowOffsets: [Int]
    public let columnIndices: [Int]
    public let values: [Scalar]
    public init(rows: Int, columns: Int, rowOffsets: [Int], columnIndices: [Int], values: [Scalar]) throws(NumericalError) {
        let offsetsCount = try NumericalWork.sum(rows, 1)
        guard rows > 0, columns > 0, rowOffsets.count == offsetsCount, columnIndices.count == values.count,
              rowOffsets.first == 0, rowOffsets.last == values.count else { throw .invalidCSR }
        guard values.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        for i in 0..<rows {
            let start = rowOffsets[i], end = rowOffsets[i + 1]
            guard start >= 0, end >= start, end <= values.count else { throw .invalidCSR }
            var previous = -1
            for k in start..<end {
                let column = columnIndices[k]
                guard column > previous, column < columns else { throw .invalidCSR }
                previous = column
            }
        }
        rowCount = rows; columnCount = columns; self.rowOffsets = rowOffsets; self.columnIndices = columnIndices; self.values = values
    }
    public func coefficient(row: Int, column: Int) throws(NumericalError) -> Scalar {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount else { throw .invalidIndex }
        return value(row: row, column: column)
    }
    func value(row: Int, column: Int) -> Scalar {
        var low = rowOffsets[row], high = rowOffsets[row + 1]
        while low < high {
            let middle = low + (high-low)/2
            if columnIndices[middle] < column { low = middle + 1 } else { high = middle }
        }
        return low < rowOffsets[row + 1] && columnIndices[low] == column ? values[low] : 0
    }
    public func applying(_ vector: [Scalar], budget: NumericalBudget) throws(NumericalError) -> [Scalar] {
        var work = NumericalWork(budget: budget)
        try work.requireStorage(try NumericalWork.sum(values.count, try NumericalWork.sum(vector.count, rowCount)))
        return try multiply(vector, work: &work)
    }
    func multiply(_ vector: [Scalar], work: inout NumericalWork) throws(NumericalError) -> [Scalar] {
        var result = [Scalar](repeating: 0, count: rowCount)
        try multiply(vector, into: &result, work: &work)
        return result
    }
    func multiply(_ vector: [Scalar], into result: inout [Scalar], work: inout NumericalWork) throws(NumericalError) {
        guard vector.count == columnCount, result.count == rowCount else { throw .invalidDimensions }
        guard vector.allSatisfy({ $0.isFinite }) else { throw .nonFiniteInput }
        try work.chargeOperations(try NumericalWork.product(2, values.count))
        for i in 0..<rowCount {
            guard !Task.isCancelled else { throw .cancelled }
            var value: Scalar = 0
            for k in rowOffsets[i]..<rowOffsets[i+1] { value += values[k] * vector[columnIndices[k]] }
            guard value.isFinite else { throw .nonFiniteResult }
            result[i] = value
        }
    }
    func validateSPDProfile(work: inout NumericalWork) throws(NumericalError) {
        guard rowCount == columnCount else { throw .invalidDimensions }
        try work.chargeOperations(try NumericalWork.product(values.count, max(1, Int.bitWidth)))
        for i in 0..<rowCount {
            guard !Task.isCancelled else { throw .cancelled }
            var offDiagonal: Scalar = 0
            for k in rowOffsets[i]..<rowOffsets[i+1] {
                guard values[k] == value(row: columnIndices[k], column: i) else { throw .nonsymmetric }
                if columnIndices[k] != i { try work.chargeOperations(2); offDiagonal += abs(values[k]) }
            }
            guard offDiagonal.isFinite else { throw .nonFiniteResult }
            let diagonal = value(row: i, column: i)
            guard diagonal > 0 else { throw .nonPositiveDefinite(pivot: i) }
            // Symmetry and strict positive diagonal dominance provide an SPD certificate without fill storage.
            guard diagonal > offDiagonal else { throw .unsupportedCapability }
        }
    }
}
