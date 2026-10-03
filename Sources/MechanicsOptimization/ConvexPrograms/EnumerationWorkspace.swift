public struct EnumerationWorkspace: Sendable {
    internal var rank: [Double] = []
    internal var kkt: [Double] = []
    internal var rhs: [Double] = []
    internal var active: [Int] = []
    internal var point: [Double] = []
    internal var equalityDual: [Double] = []
    internal var inequalityDual: [Double] = []
    public init() {}
    internal var retainedScalars: Int {
        get throws(OptimizationCause) {
            var total=try OptimizationArithmetic.sum(rank.capacity,kkt.capacity)
            total=try OptimizationArithmetic.sum(total,rhs.capacity); total=try OptimizationArithmetic.sum(total,active.capacity)
            total=try OptimizationArithmetic.sum(total,point.capacity); total=try OptimizationArithmetic.sum(total,equalityDual.capacity)
            return try OptimizationArithmetic.sum(total,inequalityDual.capacity)
        }
    }
}
