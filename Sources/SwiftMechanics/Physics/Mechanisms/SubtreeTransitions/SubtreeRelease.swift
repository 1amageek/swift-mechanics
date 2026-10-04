public final class SubtreeRelease: Sendable {
    public let sourceModel: CompiledMechanicalModel
    public let source: CompiledKinematicState
    public let sourceSnapshot: KinematicSnapshot
    public let target: CompiledMechanicalModel
    public let incomingPhysical: KinematicState
    public let removedJoint: EntityID
    public let connector: EntityID
    public let subtreeRoot: EntityID
    public let releasedBodies: [EntityID]
    public let mappings: [SubtreeJointMapping]
    public let sourceEnergy: MechanicalEnergy
    public let targetEnergy: MechanicalEnergy
    internal init(admission: _SubtreeReleaseAdmission) {
        sourceModel = admission.model; source = admission.state; sourceSnapshot = admission.snapshot
        target = admission.target; incomingPhysical = admission.target.descriptor.initialState
        removedJoint = admission.removed; connector = admission.connector; subtreeRoot = admission.root
        releasedBodies = admission.bodies; mappings = admission.mappings
        sourceEnergy = admission.before; targetEnergy = admission.after
    }
}
