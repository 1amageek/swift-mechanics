public struct Tet4FieldLocation: Sendable {
    public let meshRevision: UInt64
    public let cell: UInt64
    /// Tet4 material coordinates in the cell's original node order.
    public let barycentric: [Double]
    public init(meshRevision: UInt64, cell: UInt64, barycentric: [Double]) throws(FieldOutputError) {
        guard barycentric.count == 4, barycentric.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }) else { throw .invalidLocation }
        self.meshRevision = meshRevision; self.cell = cell; self.barycentric = barycentric
    }
}
