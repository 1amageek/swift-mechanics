public struct LinearInfeasibilityCertificate: Sendable {
    public let weights: [LinearRowMultiplier]
    public let combinedNormal: [Double]
    public let weightedRightHandSide: Double
    public let normalLowerBound: Double
    public let strictSeparationMargin: Double
    public let physicalSeparationMargin: Double
    public let maximumNormalizedNormalResidual: Double
    internal init(weights: [LinearRowMultiplier], combinedNormal: [Double], weightedRightHandSide: Double,
                  normalLowerBound: Double, strictSeparationMargin: Double, physicalSeparationMargin: Double,
                  maximumNormalizedNormalResidual: Double) {
        self.weights = weights; self.combinedNormal = combinedNormal; self.weightedRightHandSide = weightedRightHandSide
        self.normalLowerBound = normalLowerBound; self.strictSeparationMargin = strictSeparationMargin
        self.physicalSeparationMargin = physicalSeparationMargin; self.maximumNormalizedNormalResidual = maximumNormalizedNormalResidual
    }
}
