public struct RefinementProlongationRow: Sendable {
    public let refinedNode: Int, firstOriginalNode: Int
    public let secondOriginalNode: Int?
    public let firstWeight: Double, secondWeight: Double
    internal init(node: Int, first: Int, second: Int?, firstWeight: Double, secondWeight: Double) {
        self.refinedNode = node; self.firstOriginalNode = first; self.secondOriginalNode = second
        self.firstWeight = firstWeight; self.secondWeight = secondWeight
    }
}
