public protocol TriangleMeshQuerying: Sendable {
    func point(mesh: TriangleMesh, query: Vector3, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshPoint
    func ray(mesh: TriangleMesh, ray: CollisionRay, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshRayHit?
    func bounds(mesh: TriangleMesh, work: inout CollisionWork) throws(TriangleMeshError) -> CollisionBounds
    func timeOfImpact(sphere: CollisionSweep, mesh: TriangleMeshSweep, durationSeconds: Double,
                      maximumTimeWidthSeconds: Double, policy: CollisionQueryPolicy, work: inout CollisionWork)
        throws(TriangleMeshError) -> TriangleMeshSphereTOI?
}
