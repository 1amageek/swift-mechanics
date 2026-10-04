
public struct JointEncoderObservation: Sendable {
    public enum VelocityConvention: Equatable, Sendable { case orderedAxisRates, bodyAngular, parentLinearAndBodyAngular }
    public let model: ModelStamp
    public let timeSeconds: Double
    public let joint: EntityID
    public let parentAnchorFrame: EntityID
    public let positions: [Double]
    public let coordinateRates: [Double]
    public let velocities: [Double]
    public let accelerations: [Double]
    public let positionUnits: [PhysicalDimension]
    public let coordinateRateUnits: [PhysicalDimension]
    public let velocityUnits: [PhysicalDimension]
    public let accelerationUnits: [PhysicalDimension]
    public let velocityConvention: VelocityConvention
    public let accelerationAuthority: ObservationHeader.AccelerationAuthority
    public let temporalMeaning = ObservationHeader.TemporalMeaning.instantaneousContinuous
}
