public struct AttachmentPolicy: Sendable {
    public let maximumAttachments: Int
    public let maximumRows: Int
    public let maximumScalars: Int
    public let maximumIdentifierBytes: Int
    /// Positive velocity scales for rigid generalized then Cartesian nodal columns; makes rank tests dimensionless.
    public let rankColumnScales: [Double]
    /// Per-rigid-coordinate effort tolerances in the units conjugate to that coordinate's velocity.
    public let generalizedEffortTolerances: [Double]
    public let rankTolerance: Double
    public let directionTolerance: Double
    public let velocityTolerance: Double
    public let accelerationTolerance: Double
    public let gapTolerance: Double
    public let rateTolerance: Double
    public let forceTolerance: Double
    public let momentTolerance: Double
    public let powerTolerance: Double
    public let isCancelled: @Sendable () -> Bool

    public init(maximumAttachments: Int, maximumRows: Int, maximumScalars: Int,
                maximumIdentifierBytes: Int, rankColumnScales: [Double], generalizedEffortTolerances: [Double],
                rankTolerance: Double, directionTolerance: Double, velocityTolerance: Double,
                accelerationTolerance: Double,
                gapTolerance: Double, rateTolerance: Double, forceTolerance: Double,
                momentTolerance: Double, powerTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(AttachmentError) {
        guard maximumAttachments > 0, maximumRows > 0, maximumScalars > 0,
              maximumIdentifierBytes > 0, !rankColumnScales.isEmpty, rankColumnScales.count <= maximumScalars,
              generalizedEffortTolerances.count <= maximumScalars,
              rankColumnScales.allSatisfy({ $0.isFinite && $0 > 0 }),
              generalizedEffortTolerances.allSatisfy({ $0.isFinite && $0 >= 0 }),
              rankTolerance.isFinite, rankTolerance > 0,
              rankTolerance < 1, directionTolerance.isFinite, directionTolerance > 0, directionTolerance < 1,
              velocityTolerance.isFinite, velocityTolerance >= 0,
              accelerationTolerance.isFinite, accelerationTolerance >= 0,
              gapTolerance.isFinite, gapTolerance >= 0, rateTolerance.isFinite, rateTolerance >= 0,
              forceTolerance.isFinite, forceTolerance >= 0, momentTolerance.isFinite,
              momentTolerance >= 0, powerTolerance.isFinite, powerTolerance >= 0 else { throw .invalidInput }
        self.maximumAttachments = maximumAttachments; self.maximumRows = maximumRows
        self.maximumScalars = maximumScalars; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.rankColumnScales = rankColumnScales; self.generalizedEffortTolerances = generalizedEffortTolerances
        self.rankTolerance = rankTolerance; self.directionTolerance = directionTolerance
        self.velocityTolerance = velocityTolerance; self.accelerationTolerance = accelerationTolerance
        self.gapTolerance = gapTolerance; self.rateTolerance = rateTolerance
        self.forceTolerance = forceTolerance; self.momentTolerance = momentTolerance
        self.powerTolerance = powerTolerance; self.isCancelled = isCancelled
    }
}
