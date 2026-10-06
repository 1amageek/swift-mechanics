public struct PoseIKEvidence: Sendable {
    public let rowIDs: [UInt64]
    public let originalNormalizedResiduals: [Double]
    /// Ordered task records: point errors are metres; orientation errors are full matrix Frobenius distances.
    /// Pose tasks publish their point error followed by their orientation error.
    public let physicalTaskErrors: [Double]
    public let physicalTaskThresholds: [Double]
    public let loopRowIDs: [UInt64]
    public let originalLoopResiduals: [Double]
    public let minimumBoundSlack: Double
    public let rowRank: ConstraintRankEvidence?
    public let isFeasible: Bool
}
