public struct PlanarSource: Equatable, Sendable {
    public let accelerationX:Double
    public let accelerationY:Double
    public init(accelerationX:Double,accelerationY:Double) throws(PlanarFluidError) {
        guard accelerationX.isFinite,accelerationY.isFinite else { throw .nonfinite }
        self.accelerationX=accelerationX;self.accelerationY=accelerationY
    }
    internal func validate(_ grid:PlanarGrid) throws(PlanarFluidError) {
        guard abs(accelerationX) <= grid.limits.maximumAcceleration,abs(accelerationY) <= grid.limits.maximumAcceleration else { throw .domain }
    }
}
