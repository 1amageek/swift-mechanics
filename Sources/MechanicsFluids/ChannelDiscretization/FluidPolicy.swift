import MechanicsNumerics
public struct FluidPolicy: Sendable {
    public let forceAbsolute: Double
    public let forceRelative: Double
    public let pressureGradientAbsolute: Double
    public let powerAbsolute: Double
    public let powerRelative: Double
    public let energyAbsolute: Double
    public let energyRelative: Double
    public let linearTolerance: LinearTolerance<Double>
    public let isCancelled: @Sendable () -> Bool
    public init(forceAbsolute: Double, forceRelative: Double, pressureGradientAbsolute: Double,
                energyAbsolute: Double, energyRelative: Double, powerAbsolute: Double, powerRelative: Double, linearTolerance: LinearTolerance<Double>,
                isCancelled: @escaping @Sendable () -> Bool) throws(FluidError) {
        guard powerAbsolute.isFinite, powerAbsolute >= 0, powerRelative.isFinite, powerRelative >= 0, forceAbsolute.isFinite, forceAbsolute >= 0, forceRelative.isFinite, forceRelative >= 0,
              pressureGradientAbsolute.isFinite, pressureGradientAbsolute >= 0, energyAbsolute.isFinite,
              energyAbsolute >= 0, energyRelative.isFinite, energyRelative >= 0 else { throw .invalidInput }
        self.forceAbsolute=forceAbsolute; self.forceRelative=forceRelative
        self.pressureGradientAbsolute=pressureGradientAbsolute; self.energyAbsolute=energyAbsolute
        self.energyRelative=energyRelative; self.powerAbsolute=powerAbsolute; self.powerRelative=powerRelative; self.linearTolerance=linearTolerance; self.isCancelled=isCancelled
    }
    internal func poll() throws(FluidError) { guard !isCancelled(), !Task.isCancelled else { throw .cancelled } }
}
