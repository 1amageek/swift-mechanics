public protocol CompoundCollisionQuerying: Sendable {
    /// Minimum signed child-pair separation, not union minimum translation distance.
    func closest(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                 filters: CollisionFilterPolicy, policy: CollisionQueryPolicy,
                 work: inout CollisionWork) throws(CompoundCollisionError) -> CompoundCollisionWitness?
    func overlaps(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                  filters: CollisionFilterPolicy, policy: CollisionQueryPolicy,
                  work: inout CollisionWork) throws(CompoundCollisionError) -> [CompoundCollisionWitness]
    func rayHits(placement: CompoundCollisionPlacement, ray: CollisionRay, policy: CollisionQueryPolicy,
                 work: inout CollisionWork) throws(CompoundCollisionError) -> [CompoundCollisionRayHit]
}
