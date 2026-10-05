public struct RollingEvaluationPolicy: Sendable {
    public let maximumBodies: Int
    public let maximumCoordinates: Int
    public let maximumMetadataBytes: Int
    public let contactTolerance: Double
    public let minimumContactChartSine: Double
    /// Per-column characteristic generalized velocity in SI units; used only for rank.
    public let velocityScales: [Double]
    public let rankRelativeTolerance: Double
    public let requireIndependentRows: Bool
    public let absoluteVelocityTolerance: Double
    public let absoluteAccelerationTolerance: Double
    public let relativeTolerance: Double
    public let isCancelled: @Sendable () -> Bool

    public init(maximumBodies: Int, maximumCoordinates: Int, maximumMetadataBytes: Int,
                contactTolerance: Double, minimumContactChartSine: Double, velocityScales: [Double],
                rankRelativeTolerance: Double, requireIndependentRows: Bool,
                absoluteVelocityTolerance: Double, absoluteAccelerationTolerance: Double,
                relativeTolerance: Double, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(RollingError) {
        guard maximumBodies > 0, maximumCoordinates >= 0, maximumMetadataBytes > 0,
              contactTolerance.isFinite, contactTolerance > 0,
              minimumContactChartSine.isFinite, minimumContactChartSine > 0, minimumContactChartSine < 1,
              velocityScales.count <= maximumCoordinates,
              velocityScales.allSatisfy({ $0.isFinite && $0 > 0 }),
              rankRelativeTolerance.isFinite, rankRelativeTolerance > 0, rankRelativeTolerance < 1,
              absoluteVelocityTolerance.isFinite, absoluteVelocityTolerance > 0,
              absoluteAccelerationTolerance.isFinite, absoluteAccelerationTolerance > 0,
              relativeTolerance.isFinite, relativeTolerance >= 0, relativeTolerance < 1 else { throw .invalidInput }
        self.maximumBodies = maximumBodies; self.maximumCoordinates = maximumCoordinates
        self.maximumMetadataBytes = maximumMetadataBytes; self.contactTolerance = contactTolerance
        self.minimumContactChartSine = minimumContactChartSine; self.velocityScales = velocityScales
        self.rankRelativeTolerance = rankRelativeTolerance; self.requireIndependentRows = requireIndependentRows
        self.absoluteVelocityTolerance = absoluteVelocityTolerance
        self.absoluteAccelerationTolerance = absoluteAccelerationTolerance; self.relativeTolerance = relativeTolerance
        self.isCancelled = isCancelled
    }
}
