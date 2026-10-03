public struct TreeTangentWorkspace: Sendable {
    internal var frames: [DifferentialFrame] = []
    internal var columns: [DifferentialMotion] = []
    internal var prefixes: [DifferentialFrame] = []
    internal var localColumns: [DifferentialMotion] = []
    public init() {}
    internal func retainedScalarSlots() throws(DerivativeError) -> Int {
        try DifferentialArithmetic.sum(DifferentialArithmetic.product(frames.count,48),
            DifferentialArithmetic.sum(DifferentialArithmetic.product(columns.count,12),
                DifferentialArithmetic.sum(DifferentialArithmetic.product(prefixes.count,48),DifferentialArithmetic.product(localColumns.count,12))))
    }
}
