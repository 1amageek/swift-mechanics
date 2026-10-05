public struct HydrodynamicDragLaw: Sendable, Equatable {
    /// Coefficients have units N*s^2/m^2 and are caller calibrated.
    public let axialCoefficient: Double
    public let transverseCoefficient: Double
    public let maximumRelativeSpeed: Double
    public init(axialCoefficient: Double, transverseCoefficient: Double, maximumRelativeSpeed: Double) throws(LoadError) {
        guard axialCoefficient.isFinite, axialCoefficient >= 0, transverseCoefficient.isFinite,
              transverseCoefficient >= 0, maximumRelativeSpeed.isFinite, maximumRelativeSpeed > 0 else { throw .invalidInput }
        self.axialCoefficient = axialCoefficient; self.transverseCoefficient = transverseCoefficient
        self.maximumRelativeSpeed = maximumRelativeSpeed
    }
}
