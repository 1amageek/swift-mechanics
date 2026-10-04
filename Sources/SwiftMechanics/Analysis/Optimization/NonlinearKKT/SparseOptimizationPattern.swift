public struct SparseOptimizationPattern: Sendable {
    public let rows: Int, columns: Int
    public let rowOffsets: [Int], columnIndices: [Int]
    public init(rows: Int,columns: Int,rowOffsets: [Int],columnIndices: [Int]) {
        self.rows=rows; self.columns=columns; self.rowOffsets=rowOffsets; self.columnIndices=columnIndices
    }
}
