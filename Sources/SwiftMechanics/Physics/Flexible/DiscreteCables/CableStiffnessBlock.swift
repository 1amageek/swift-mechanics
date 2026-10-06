public struct CableStiffnessBlock: Equatable, Sendable {
    public let rowNode: Int
    public let columnNode: Int
    public let value: Matrix3
    internal init(rowNode: Int, columnNode: Int, value: Matrix3) {
        self.rowNode = rowNode; self.columnNode = columnNode; self.value = value
    }
}
