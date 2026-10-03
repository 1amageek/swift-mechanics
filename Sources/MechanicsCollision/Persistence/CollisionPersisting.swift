public protocol CollisionPersisting: Sendable {
    func manifold(first: CollisionProxy, second: CollisionProxy, current: [CollisionWitness],
                  previous: CollisionManifold?, manifoldPolicy: CollisionManifoldPolicy,
                  queryPolicy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionManifold
    func triggers(snapshot: CollisionSnapshot, filters: CollisionFilterPolicy,
                  previous: CollisionTriggerState?, sampleIndex: UInt64,
                  policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionTriggerUpdate
}
