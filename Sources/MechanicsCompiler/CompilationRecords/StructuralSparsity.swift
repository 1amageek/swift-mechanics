public struct StructuralSparsity: Equatable, Sendable {
    public let rowCount: Int
    public let columnCount: Int
    public let rowOffsets: [Int]
    public let columnIndices: [Int]

    internal init(rowCount: Int, columnCount: Int, rowOffsets: [Int], columnIndices: [Int]) {
        self.rowCount = rowCount; self.columnCount = columnCount; self.rowOffsets = rowOffsets; self.columnIndices = columnIndices
    }

    public func contains(row: Int, column: Int) throws(CompilationFailure) -> Bool {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount else {
            throw .one(.invalidInput, .layout, message: "Sparsity index is outside the compiled layout.")
        }
        return columnIndices[rowOffsets[row]..<rowOffsets[row + 1]].contains(column)
    }
}
