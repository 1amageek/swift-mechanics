
/// A full retained-row reaction representative. Redundant row multipliers are not unique.
public final class ConstrainedMotion: Sendable {
    public enum TemporalMeaning: Sendable { case accelerationForce, instantaneousVelocityImpulse }
    public let values: [Double]
    /// Joules for force reactions; joule-seconds for instantaneous impulses.
    public let rowMultipliers: [Double]
    public let rowIDs: [UInt64]
    public let generalizedReaction: [Double]
    public let rank: ConstraintRankEvidence
    public let layout: ConstraintCoordinateLayout
    public let basis: TreeCoordinateLayout
    public let frame: EntityID
    public let sourceSnapshot: KinematicSnapshot
    public let sourceVelocity: [Double]
    public let originalRowResidual: Double
    public let originalPhysicalResidual: Double
    public let kineticEnergyChange: Double?
    public let time: Double
    public let temporalMeaning: TemporalMeaning
    internal init(values:[Double], multipliers:[Double], ids:[UInt64], reaction:[Double], rank:ConstraintRankEvidence,layout:ConstraintCoordinateLayout,basis:TreeCoordinateLayout,frame:EntityID,source:KinematicSnapshot,velocity:[Double],
                  rowResidual:Double, physicalResidual:Double, energy:Double?, time:Double, meaning:TemporalMeaning) {
        self.values=values; rowMultipliers=multipliers; rowIDs=ids; generalizedReaction=reaction; self.rank=rank;self.layout=layout;self.basis=basis;self.frame=frame;sourceSnapshot=source;sourceVelocity=velocity
        originalRowResidual=rowResidual; originalPhysicalResidual=physicalResidual; kineticEnergyChange=energy; self.time=time; temporalMeaning=meaning
    }
}
