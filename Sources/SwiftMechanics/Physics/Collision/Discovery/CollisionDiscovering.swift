public protocol CollisionDiscovering: Sendable {
    func candidates(snapshot: CollisionSnapshot, endpoint: CollisionSnapshot?, filters: CollisionFilterPolicy,
                    policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionPairKey]
    func overlaps(snapshot: CollisionSnapshot, filters: CollisionFilterPolicy,
                  policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionWitness]
    func rayHits(snapshot: CollisionSnapshot, ray: CollisionRay,
                 policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionRayHit]
}
