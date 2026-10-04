import SwiftMechanics
internal struct FailingPlaneQueries: CollisionGeometryQuerying {
    private let base=AnalyticCollisionQueries()
    func witness(first: CollisionProxy, second: CollisionProxy, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionWitness { try base.witness(first:first,second:second,policy:policy,work:&work) }
    func support(proxy: CollisionProxy, direction: Vector3, work: inout CollisionWork) throws(CollisionError) -> CollisionSupport { try base.support(proxy:proxy,direction:direction,work:&work) }
    func point(proxy: CollisionProxy, query: Vector3, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionPointResult { try work.charge(64); throw .invalidShape }
    func ray(proxy: CollisionProxy, ray: CollisionRay, policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionRayHit? { try base.ray(proxy:proxy,ray:ray,policy:policy,work:&work) }
    func bounds(proxy: CollisionProxy, work: inout CollisionWork) throws(CollisionError) -> CollisionBounds { try base.bounds(proxy:proxy,work:&work) }
}
