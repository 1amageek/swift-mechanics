import MechanicsNumerics
public struct PlanarPolicy: Sendable {
    public let divergenceAbsolute:Double
    public let pressureAbsolute:Double
    public let pressureRelative:Double
    public let forceAbsolute:Double
    public let forceRelative:Double
    public let energyAbsolute:Double
    public let energyRelative:Double
    public let courantLimit:Double
    public let linearTolerance:LinearTolerance<Double>
    public let isCancelled:@Sendable ()->Bool
    public init(divergenceAbsolute:Double,pressureAbsolute:Double,pressureRelative:Double,forceAbsolute:Double,
                forceRelative:Double,energyAbsolute:Double,energyRelative:Double,courantLimit:Double,
                linearTolerance:LinearTolerance<Double>,isCancelled:@escaping @Sendable ()->Bool) throws(PlanarFluidError) {
        guard divergenceAbsolute.isFinite,divergenceAbsolute >= 0,pressureAbsolute.isFinite,pressureAbsolute >= 0,
              pressureRelative.isFinite,pressureRelative >= 0,forceAbsolute.isFinite,forceAbsolute >= 0,
              forceRelative.isFinite,forceRelative >= 0,energyAbsolute.isFinite,energyAbsolute >= 0,
              energyRelative.isFinite,energyRelative >= 0,courantLimit.isFinite,courantLimit > 0,courantLimit <= 1 else { throw .invalidInput }
        self.divergenceAbsolute=divergenceAbsolute;self.pressureAbsolute=pressureAbsolute;self.pressureRelative=pressureRelative
        self.forceAbsolute=forceAbsolute;self.forceRelative=forceRelative;self.energyAbsolute=energyAbsolute;self.energyRelative=energyRelative
        self.courantLimit=courantLimit;self.linearTolerance=linearTolerance;self.isCancelled=isCancelled
    }
    internal func poll() throws(PlanarFluidError) { guard !Task.isCancelled,!isCancelled() else { throw .cancelled } }
}
