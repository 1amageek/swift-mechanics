public struct OptimizationInfeasibility: Sendable {
    public let equalityWeights: [Double], inequalityWeights: [Double], lowerWeights: [Double], upperWeights: [Double]
    public let originalNormalResidual: Double, originalRightHandSide: Double, threshold: Double, boundedNormalError: Double, strictSeparationMargin: Double
    internal init(equality: [Double], inequality: [Double], lower: [Double], upper: [Double], residual: Double, rhs: Double, threshold: Double, boundedError: Double, margin: Double) {
        equalityWeights=equality; inequalityWeights=inequality; lowerWeights=lower; upperWeights=upper
        originalNormalResidual=residual; originalRightHandSide=rhs; self.threshold=threshold; boundedNormalError=boundedError; strictSeparationMargin=margin
    }
}
