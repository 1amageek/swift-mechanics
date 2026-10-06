public struct SpatialState: Equatable, Sendable {
    public let grid:SpatialGrid
    public let time:Double
    public let sequence:UInt64
    public let u:[Double]
    public let v:[Double]
    public let w:[Double]
    public let pressure:[Double]
    public let source:SpatialSource
    public init(grid:SpatialGrid,time:Double,sequence:UInt64,u:[Double],v:[Double],w:[Double],pressure:[Double],
                source:SpatialSource) throws(SpatialFluidError) {
        guard u.count == grid.count,v.count == grid.count,w.count == grid.count,pressure.count == grid.count else { throw .staleBinding }
        guard time.isFinite,time >= 0 else { throw .invalidInput }
        try source.validate(grid)
        for k in 0..<grid.count {
            guard u[k].isFinite,v[k].isFinite,w[k].isFinite,pressure[k].isFinite else { throw .nonfinite }
            guard abs(u[k]) <= grid.limits.maximumSpeed,abs(v[k]) <= grid.limits.maximumSpeed,
                  abs(w[k]) <= grid.limits.maximumSpeed,abs(pressure[k]) <= grid.limits.maximumPressure else { throw .domain }
        }
        self.grid=grid;self.time=time;self.sequence=sequence;self.u=u;self.v=v;self.w=w;self.pressure=pressure;self.source=source
    }
    internal func component(_ axis:Int)->[Double] { axis == 0 ? u : (axis == 1 ? v : w) }
}
