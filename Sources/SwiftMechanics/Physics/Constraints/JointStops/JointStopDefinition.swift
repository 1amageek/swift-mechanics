/// Explicit caller-owned bounds; not an inferred compiler or foreign-format limit inventory.
public struct JointStopDefinition: Sendable {
    public let model: ModelStamp
    public let joint: EntityID
    public let coordinateUnit: PhysicalDimension
    public let lower: Double
    public let upper: Double
    public let wrap: JointWrapPolicy
    /// Exactly 1 m/m for prismatic; explicit positive stop arc radius in m/rad for rotary.
    public let metersPerCoordinateUnit: Double
    public let restitutionLaw: ContactLawPair
    public init(model: ModelStamp, joint: EntityID, coordinateUnit: PhysicalDimension, lower: Double, upper: Double,
                wrap: JointWrapPolicy, metersPerCoordinateUnit: Double, restitutionLaw: ContactLawPair) throws(JointStopFailure) {
        guard joint.kind == .joint, coordinateUnit == .angle || coordinateUnit == .length,
              lower.isFinite, upper.isFinite, lower < upper, metersPerCoordinateUnit.isFinite,
              metersPerCoordinateUnit > 0 else { throw JointStopFailure(.invalidInput) }
        self.model=model; self.joint=joint; self.coordinateUnit=coordinateUnit; self.lower=lower; self.upper=upper
        self.wrap=wrap; self.metersPerCoordinateUnit=metersPerCoordinateUnit; self.restitutionLaw=restitutionLaw
    }
}
