public struct PlanarState: Equatable, Sendable {
    public let grid:PlanarGrid
    public let time:Double
    public let sequence:UInt64
    public let u:[Double]
    public let v:[Double]
    public let pressure:[Double]
    public let source:PlanarSource
    public init(grid:PlanarGrid,time:Double,sequence:UInt64,u:[Double],v:[Double],pressure:[Double],
                source:PlanarSource) throws(PlanarFluidError) {
        guard u.count == grid.count,v.count == grid.count,pressure.count == grid.count else { throw .staleBinding }
        guard time.isFinite,time >= 0,pressure[0] == 0 else { throw .invalidInput }
        try source.validate(grid)
        for k in 0..<grid.count {
            guard u[k].isFinite,v[k].isFinite,pressure[k].isFinite else { throw .nonfinite }
            guard abs(u[k]) <= grid.limits.maximumSpeed,abs(v[k]) <= grid.limits.maximumSpeed,
                  abs(pressure[k]) <= grid.limits.maximumPressure else { throw .domain }
        }
        self.grid=grid;self.time=time;self.sequence=sequence;self.u=u;self.v=v;self.pressure=pressure;self.source=source
    }
}
