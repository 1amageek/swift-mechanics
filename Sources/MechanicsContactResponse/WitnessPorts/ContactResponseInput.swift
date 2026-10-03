import MechanicsCollision
import MechanicsDynamics
public struct ContactResponseInput: Sendable {
    public let system: RigidDynamicsSystem
    public let collision: CollisionSnapshot
    public let expectedCollisionRevision: UInt64
    public let expectedModelRevision: UInt64
    public let contacts: [WitnessContact]
    public let driveForce: [Double]
    public let timeStep: Double
    public init(system: RigidDynamicsSystem, collision: CollisionSnapshot, expectedCollisionRevision: UInt64,
                expectedModelRevision: UInt64, contacts: [WitnessContact], driveForce: [Double], timeStep: Double) throws(ContactResponseError) {
        guard timeStep.isFinite, timeStep > 0, (timeStep*timeStep).isFinite, timeStep*timeStep > 0 else { throw .invalidInput }
        self.system=system; self.collision=collision; self.expectedCollisionRevision=expectedCollisionRevision
        self.expectedModelRevision=expectedModelRevision; self.contacts=contacts; self.driveForce=driveForce; self.timeStep=timeStep
    }
}
