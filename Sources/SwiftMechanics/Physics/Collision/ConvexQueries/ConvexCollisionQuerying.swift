public protocol ConvexCollisionQuerying: Sendable {
    func support(proxy: ConvexProxy, direction: Vector3, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexSupport
    func witness(first: ConvexProxy, second: ConvexProxy,
                 policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexCollisionWitness
    func witness(first: CollisionProxy, second: CollisionProxy,
                 policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(ConvexCollisionError) -> ConvexCollisionWitness
}
