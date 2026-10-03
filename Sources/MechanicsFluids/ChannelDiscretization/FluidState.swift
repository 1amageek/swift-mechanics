public struct FluidState: Equatable, Sendable {
    public let channel: FluidChannel
    public let boundary: FluidBoundary
    public let time: Double
    public let sequence: UInt64
    public let velocities: [Double]
    public let pressureFaces: [Double]
    internal init(channel: FluidChannel, boundary: FluidBoundary, time: Double, sequence: UInt64,
                  velocities: [Double], pressureFaces: [Double]) {
        self.channel=channel; self.boundary=boundary; self.time=time; self.sequence=sequence
        self.velocities=velocities; self.pressureFaces=pressureFaces
    }
    internal func validate() throws(FluidError) {
        try boundary.validate(channel:channel)
        guard time.isFinite, time >= 0, velocities.count == channel.cells,
              pressureFaces.count == channel.cells+1 else { throw .invalidInput }
        guard pressureFaces[0] == boundary.lowerGaugePressure else { throw .originalResidual }
        for u in velocities { guard u.isFinite else { throw .nonfinite }; guard abs(u) <= channel.limits.maximumSpeed else { throw .domain } }
        for p in pressureFaces { guard p.isFinite else { throw .nonfinite }; guard abs(p) <= channel.limits.maximumPressure else { throw .domain } }
    }
}
