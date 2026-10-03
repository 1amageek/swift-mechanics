public struct MechanicalDerivativeWorkspace: Sendable {
    public var tree = TreeTangentWorkspace()
    internal var callbackValue: [Double] = []
    internal var callbackDirection: [Double] = []
    internal var rightHandSide: [Double] = []
    internal var originalDirection: [Double] = []
    public init() {}
    internal func retainedScalarSlots() throws(DerivativeError) -> Int {
        try DifferentialArithmetic.sum(tree.retainedScalarSlots(),
            DifferentialArithmetic.sum(DifferentialArithmetic.sum(callbackValue.count,callbackDirection.count),
                DifferentialArithmetic.sum(rightHandSide.count,originalDirection.count)))
    }
}
