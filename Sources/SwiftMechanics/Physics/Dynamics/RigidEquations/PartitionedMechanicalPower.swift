/// Full original energy and coordinate balance; known-coordinate power does not become anchor drift.
public final class PartitionedMechanicalPower: Sendable {
    public let system: PhysicalRigidDynamicsSystem
    public let acceleration: [Double]
    public let knownCoordinates: [Int]
    public let drive: [Double]
    public let geometricReaction: [Double]
    public let energy: MechanicalEnergy
    public let originalGeneralizedInertialForce: [Double]
    /// Efforts in the same order as knownCoordinates, after original known loads and geometric reaction.
    public let rootActuationEffort: [Double]
    public let knownCoordinatePower: Double
    public let dynamicCoordinatePower: Double
    public let rootActuationPower: Double
    public let geometricReactionPower: Double
    public let anchorPrescribedPower: Double
    public let drivePower: Double
    public let knownLoadPower: Double
    internal init(system: PhysicalRigidDynamicsSystem, acceleration: [Double], knownCoordinates: [Int],
                  drive: [Double], geometricReaction: [Double], energy: MechanicalEnergy, original: [Double], effort: [Double],
                  known: Double, dynamic: Double, actuation: Double, reaction: Double, drivePower: Double, loads: Double) {
        self.system=system;self.acceleration=acceleration;self.knownCoordinates=knownCoordinates;self.drive=drive
        self.geometricReaction=geometricReaction;self.energy=energy;originalGeneralizedInertialForce=original
        rootActuationEffort=effort;knownCoordinatePower=known;dynamicCoordinatePower=dynamic;rootActuationPower=actuation
        geometricReactionPower=reaction;anchorPrescribedPower=energy.requiredPrescribedPower;self.drivePower=drivePower;knownLoadPower=loads
    }
}
