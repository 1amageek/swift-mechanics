public struct CablePolicy: Sendable {
    public let maximumNodes: Int
    public let maximumMetadataBytes: Int
    public let minimumSegmentLength: Double
    public let maximumAttempts: Int
    public let minimumSubstep: Double
    public let absoluteEnergyTolerance: Double
    public let absoluteMomentumTolerance: Double
    public let absoluteAngularMomentumTolerance: Double
    public let relativeTolerance: Double
    public let isCancelled: @Sendable () -> Bool

    public init(maximumNodes: Int, maximumMetadataBytes: Int, minimumSegmentLength: Double,
                maximumAttempts: Int, minimumSubstep: Double, absoluteEnergyTolerance: Double,
                absoluteMomentumTolerance: Double, absoluteAngularMomentumTolerance: Double,
                relativeTolerance: Double, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(CableError) {
        guard maximumNodes >= 2, maximumMetadataBytes > 0, minimumSegmentLength.isFinite,
              minimumSegmentLength > 0, maximumAttempts > 0, minimumSubstep.isFinite, minimumSubstep > 0,
              absoluteEnergyTolerance.isFinite, absoluteEnergyTolerance >= 0,
              absoluteMomentumTolerance.isFinite, absoluteMomentumTolerance >= 0,
              absoluteAngularMomentumTolerance.isFinite, absoluteAngularMomentumTolerance >= 0,
              relativeTolerance.isFinite, relativeTolerance >= 0 else { throw .invalidInput }
        self.maximumNodes = maximumNodes; self.maximumMetadataBytes = maximumMetadataBytes
        self.minimumSegmentLength = minimumSegmentLength; self.maximumAttempts = maximumAttempts
        self.minimumSubstep = minimumSubstep; self.absoluteEnergyTolerance = absoluteEnergyTolerance
        self.absoluteMomentumTolerance = absoluteMomentumTolerance
        self.absoluteAngularMomentumTolerance = absoluteAngularMomentumTolerance
        self.relativeTolerance = relativeTolerance; self.isCancelled = isCancelled
    }
}
