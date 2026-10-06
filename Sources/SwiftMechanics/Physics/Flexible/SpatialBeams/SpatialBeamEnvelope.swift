/// Calibrated dimensionless limits, not a finite-rotation capability claim.
public struct SpatialBeamEnvelope: Equatable, Sendable {
    public let maximumRotation: Double
    public let maximumSlope: Double
    public let maximumFiberStrain: Double
    public let maximumShear: Double
    public let maximumTwistDistortion: Double
    public init(maximumRotation: Double, maximumSlope: Double, maximumFiberStrain: Double,
                maximumShear: Double, maximumTwistDistortion: Double) throws(SpatialBeamError) {
        for value in [maximumRotation, maximumSlope, maximumFiberStrain, maximumShear, maximumTwistDistortion] {
            guard value.isFinite, value > 0, value < 1 else { throw .invalidInput(parameter: "linearEnvelope") }
        }
        self.maximumRotation = maximumRotation; self.maximumSlope = maximumSlope
        self.maximumFiberStrain = maximumFiberStrain; self.maximumShear = maximumShear
        self.maximumTwistDistortion = maximumTwistDistortion
    }
}
