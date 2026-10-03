import MechanicsCore

public protocol CollisionGeometryQuerying: Sendable {
    func witness(first: CollisionProxy, second: CollisionProxy, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionWitness
    func support(proxy: CollisionProxy, direction: Vector3, work: inout CollisionWork) throws(CollisionError) -> CollisionSupport
    func point(proxy: CollisionProxy, query: Vector3, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionPointResult
    func ray(proxy: CollisionProxy, ray: CollisionRay, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionRayHit?
    func bounds(proxy: CollisionProxy, work: inout CollisionWork) throws(CollisionError) -> CollisionBounds
}
