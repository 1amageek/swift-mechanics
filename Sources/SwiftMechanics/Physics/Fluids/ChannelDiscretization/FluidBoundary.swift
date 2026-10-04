public struct FluidBoundary: Equatable, Sendable {
    public let lowerSpeed: Double
    public let upperSpeed: Double
    public let pressureGradientX: Double
    public let lowerGaugePressure: Double
    public init(lowerSpeed: Double, upperSpeed: Double, pressureGradientX: Double, lowerGaugePressure: Double) throws(FluidError) {
        guard lowerSpeed.isFinite, upperSpeed.isFinite, pressureGradientX.isFinite, lowerGaugePressure.isFinite else { throw .nonfinite }
        self.lowerSpeed=lowerSpeed; self.upperSpeed=upperSpeed
        self.pressureGradientX=pressureGradientX; self.lowerGaugePressure=lowerGaugePressure
    }
    internal func validate(channel: FluidChannel) throws(FluidError) {
        guard abs(lowerSpeed) <= channel.limits.maximumSpeed, abs(upperSpeed) <= channel.limits.maximumSpeed,
              abs(lowerGaugePressure) <= channel.limits.maximumPressure else { throw .domain }
        let force=try fluidFinite(-pressureGradientX+channel.density*channel.accelerationX)
        guard abs(force) <= channel.limits.maximumSource else { throw .domain }
    }
}
