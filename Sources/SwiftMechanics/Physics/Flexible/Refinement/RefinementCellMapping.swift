public struct RefinementCellMapping: Sendable {
    public let originalCell: TetrahedronCell
    public let children: [UInt64]
    public let diagonalMidpoints: [Int]
    public let originalReferenceVolume: Double, refinedReferenceVolume: Double
    public let originalCurrentVolume: Double, refinedCurrentVolume: Double
    internal init(cell: TetrahedronCell, children: [UInt64], diagonal: [Int], reference: Double,
                  refinedReference: Double, current: Double, refinedCurrent: Double) {
        self.originalCell = cell; self.children = children; self.diagonalMidpoints = diagonal
        self.originalReferenceVolume = reference; self.refinedReferenceVolume = refinedReference
        self.originalCurrentVolume = current; self.refinedCurrentVolume = refinedCurrent
    }
}
