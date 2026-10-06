import SwiftMechanics

struct ForeignWitnessGeometry:CollisionGeometryQuerying {
    func witness(first:CollisionProxy,second:CollisionProxy,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->CollisionWitness {
        let translated:Vector3
        do throws(CoreError) { translated=try first.pose.translation.adding(Vector3(0.1,0,0)) } catch { throw .core(error) }
        return try AnalyticCollisionQueries().witness(first:first.moved(to:RigidTransform(rotation:first.pose.rotation,translation:translated)),second:second,policy:policy,work:&work)
    }
    func support(proxy:CollisionProxy,direction:Vector3,work:inout CollisionWork) throws(CollisionError)->CollisionSupport { try AnalyticCollisionQueries().support(proxy:proxy,direction:direction,work:&work) }
    func point(proxy:CollisionProxy,query:Vector3,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->CollisionPointResult { try AnalyticCollisionQueries().point(proxy:proxy,query:query,policy:policy,work:&work) }
    func ray(proxy:CollisionProxy,ray:CollisionRay,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->CollisionRayHit? { try AnalyticCollisionQueries().ray(proxy:proxy,ray:ray,policy:policy,work:&work) }
    func bounds(proxy:CollisionProxy,work:inout CollisionWork) throws(CollisionError)->CollisionBounds { try AnalyticCollisionQueries().bounds(proxy:proxy,work:&work) }
}
