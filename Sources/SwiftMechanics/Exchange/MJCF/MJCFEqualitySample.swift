/// Original affine residual in metres; nonzero residual does not imply assembly success.
public struct MJCFEqualitySample: Sendable {
    public let rowID: UInt64
    public let node: Int
    public let residualSI: Double
    public let gradientSI: [Double]
    public let originalReplayErrorSI: Double
    internal init(rowID: UInt64, node: Int, residualSI: Double, gradientSI: [Double], originalReplayErrorSI: Double) {
        self.rowID = rowID; self.node = node; self.residualSI = residualSI; self.gradientSI = gradientSI; self.originalReplayErrorSI = originalReplayErrorSI
    }
}
