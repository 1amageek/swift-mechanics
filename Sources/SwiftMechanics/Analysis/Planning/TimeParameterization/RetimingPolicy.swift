public struct RetimingPolicy: Sendable {
    public let maximumWaypoints: Int
    public let maximumCoordinates: Int
    public let maximumBodies: Int
    public let minimumSegmentDuration: Double
    public let maximumSegmentDuration: Double
    public let maximumTotalDuration: Double
    /// Relative envelope for finite Float64 arithmetic and duration rounding.
    public let safetyFactor: Double
    public let jointPolicy: JointEvaluationPolicy
    public let dynamicsAdmission: DynamicsAdmission
    public let physicalAgreement: NumericalTolerance
    public let isCancelled: @Sendable () -> Bool
    public init(maximumWaypoints: Int, maximumCoordinates: Int, maximumBodies: Int,
                minimumSegmentDuration: Double, maximumSegmentDuration: Double,
                maximumTotalDuration: Double, safetyFactor: Double,
                jointPolicy: JointEvaluationPolicy, dynamicsAdmission: DynamicsAdmission,
                physicalAgreement: NumericalTolerance, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(RetimingError) {
        guard maximumWaypoints >= 2, maximumCoordinates > 0, maximumBodies > 0,
              minimumSegmentDuration.isFinite, minimumSegmentDuration > 0,
              maximumSegmentDuration.isFinite, maximumSegmentDuration >= minimumSegmentDuration,
              maximumTotalDuration.isFinite, maximumTotalDuration >= minimumSegmentDuration,
              safetyFactor.isFinite, safetyFactor >= 1 + 128 * Double.ulpOfOne, safetyFactor <= 2 else { throw .invalidPolicy }
        self.maximumWaypoints = maximumWaypoints; self.maximumCoordinates = maximumCoordinates
        self.maximumBodies = maximumBodies; self.minimumSegmentDuration = minimumSegmentDuration
        self.maximumSegmentDuration = maximumSegmentDuration; self.maximumTotalDuration = maximumTotalDuration
        self.safetyFactor = safetyFactor; self.jointPolicy = jointPolicy; self.dynamicsAdmission = dynamicsAdmission
        self.physicalAgreement = physicalAgreement; self.isCancelled = isCancelled
    }
}
