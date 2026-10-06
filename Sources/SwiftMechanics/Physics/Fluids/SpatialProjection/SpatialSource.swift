public struct SpatialSource: Equatable, Sendable {
    public let accelerationX:Double
    public let accelerationY:Double
    public let accelerationZ:Double
    public init(accelerationX:Double,accelerationY:Double,accelerationZ:Double) throws(SpatialFluidError) {
        guard accelerationX.isFinite,accelerationY.isFinite,accelerationZ.isFinite else { throw .nonfinite }
        self.accelerationX=accelerationX;self.accelerationY=accelerationY;self.accelerationZ=accelerationZ
    }
    internal func validate(_ grid:SpatialGrid) throws(SpatialFluidError) {
        guard abs(accelerationX) <= grid.limits.maximumAcceleration,abs(accelerationY) <= grid.limits.maximumAcceleration,abs(accelerationZ) <= grid.limits.maximumAcceleration else { throw .domain }
    }
    internal func component(_ axis:Int)->Double { axis == 0 ? accelerationX : (axis == 1 ? accelerationY : accelerationZ) }
}
