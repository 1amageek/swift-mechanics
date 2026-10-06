/// One identified original analytic contact and the retained physical source at the jump.
/// The source is an unconstrained spatial tree; constrained or simultaneous-contact inventories are not represented.
public struct FrictionalImpulseInput: Sendable {
    public let tree: KinematicTree
    public let state: KinematicState
    public let inertias: [RigidBodyInertia]
    public let collision: CollisionSnapshot
    public let expectedCollisionRevision: UInt64
    public let contact: ImpulseContactBinding
    public let basis: ContactBasis
    public init(tree: KinematicTree, state: KinematicState, inertias: [RigidBodyInertia], collision: CollisionSnapshot,
                expectedCollisionRevision: UInt64, contact: ImpulseContactBinding, basis: ContactBasis) {
        self.tree=tree; self.state=state; self.inertias=inertias; self.collision=collision
        self.expectedCollisionRevision=expectedCollisionRevision; self.contact=contact; self.basis=basis
    }
}
