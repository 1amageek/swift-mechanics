public struct SpatialBeamAdmission: Sendable {
    public let maximumMetadataBytes: Int
    public let minimumOrientationSine: Double
    public let minimumSlenderness: Double
    public let maximumSlenderness: Double
    /// Joules after translation coordinates are scaled by element length.
    public let normalizedOperatorTolerance: NumericalTolerance
    public let energyTolerance: NumericalTolerance
    public let powerTolerance: NumericalTolerance
    public let forceTolerance: NumericalTolerance
    public let momentTolerance: NumericalTolerance
    public let isCancelled: @Sendable () -> Bool

    public init(maximumMetadataBytes: Int, minimumOrientationSine: Double,
                minimumSlenderness: Double, maximumSlenderness: Double,
                normalizedOperatorTolerance: NumericalTolerance, energyTolerance: NumericalTolerance,
                powerTolerance: NumericalTolerance, forceTolerance: NumericalTolerance,
                momentTolerance: NumericalTolerance, isCancelled: @escaping @Sendable () -> Bool) throws(SpatialBeamError) {
        guard maximumMetadataBytes > 0, minimumOrientationSine.isFinite,
              minimumOrientationSine > 0, minimumOrientationSine <= 1,
              minimumSlenderness.isFinite, maximumSlenderness.isFinite,
              minimumSlenderness > 0, maximumSlenderness >= minimumSlenderness else {
            throw .invalidInput(parameter: "admission")
        }
        self.maximumMetadataBytes = maximumMetadataBytes; self.minimumOrientationSine = minimumOrientationSine
        self.minimumSlenderness = minimumSlenderness; self.maximumSlenderness = maximumSlenderness
        self.normalizedOperatorTolerance = normalizedOperatorTolerance; self.energyTolerance = energyTolerance
        self.powerTolerance = powerTolerance; self.forceTolerance = forceTolerance; self.momentTolerance = momentTolerance
        self.isCancelled = isCancelled
    }
}
