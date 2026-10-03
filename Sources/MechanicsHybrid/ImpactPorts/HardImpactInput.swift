import MechanicsCompiler
import MechanicsDynamics
import MechanicsCollision

public struct HardImpactInput: Sendable {
    public let model: CompiledMechanicalModel
    public let physical: CompiledKinematicState
    public let inertias: [RigidBodyInertia]
    public let collision: CollisionSnapshot
    public let expectedCollisionRevision: UInt64
    public let contacts: [ImpulseContactBinding]
    public init(model: CompiledMechanicalModel, physical: CompiledKinematicState, inertias: [RigidBodyInertia],
                collision: CollisionSnapshot, expectedCollisionRevision: UInt64, contacts: [ImpulseContactBinding]) {
        self.model=model; self.physical=physical; self.inertias=inertias; self.collision=collision
        self.expectedCollisionRevision=expectedCollisionRevision; self.contacts=contacts
    }
}
