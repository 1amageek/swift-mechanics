/// Exact supplier witness with retained assembly and original local child attribution.
public struct CompoundCollisionWitness: Sendable {
    public let firstAssembly: CompoundCollisionIdentity
    public let secondAssembly: CompoundCollisionIdentity
    public let firstLocalChild: CollisionProxy
    public let secondLocalChild: CollisionProxy
    public let witness: CollisionWitness

    internal init(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                  firstLocalChild: CollisionProxy, secondLocalChild: CollisionProxy, witness: CollisionWitness) {
        firstAssembly = first.compound.identity; secondAssembly = second.compound.identity
        self.firstLocalChild = firstLocalChild; self.secondLocalChild = secondLocalChild; self.witness = witness
    }
}
