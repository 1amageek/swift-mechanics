/// SI calibration of a homogeneous barotropic liquid; heat does not alter its EOS.
public struct ParticleFlowMaterial: Equatable, Sendable {
    public let referenceDensity: Double
    public let referenceSoundSpeed: Double
    public let taitExponent: Int
    public let dynamicViscosity: Double
    public let smoothingLength: Double
    public let viscosityRegularization: Double
    public init(referenceDensity: Double, referenceSoundSpeed: Double, taitExponent: Int,
                dynamicViscosity: Double, smoothingLength: Double,
                viscosityRegularization: Double) throws(ParticleFlowError) {
        guard referenceDensity.isFinite, referenceDensity > 0,
              referenceSoundSpeed.isFinite, referenceSoundSpeed > 0, taitExponent >= 2,
              Double(taitExponent) <= 9_007_199_254_740_991,
              dynamicViscosity.isFinite, dynamicViscosity >= 0,
              smoothingLength.isFinite, smoothingLength > 0,
              viscosityRegularization.isFinite, viscosityRegularization > 0 else { throw .invalidInput }
        self.referenceDensity = referenceDensity; self.referenceSoundSpeed = referenceSoundSpeed
        self.taitExponent = taitExponent; self.dynamicViscosity = dynamicViscosity
        self.smoothingLength = smoothingLength; self.viscosityRegularization = viscosityRegularization
    }
}
