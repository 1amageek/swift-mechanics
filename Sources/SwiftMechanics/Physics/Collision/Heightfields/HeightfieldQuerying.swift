public protocol HeightfieldQuerying: Sendable {
    func closest(field: GridHeightfield, expected: HeightfieldReference, query: Vector3,
                 policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldPoint
    func ray(field: GridHeightfield, expected: HeightfieldReference, ray: CollisionRay,
             policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldRayHit?
    func overlap(field: GridHeightfield, expected: HeightfieldReference, sphere: CollisionProxy,
                 policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldSphereOverlap
    func bounds(field: GridHeightfield, work: inout CollisionWork) throws(HeightfieldError) -> CollisionBounds
    func signedSolidDistance(field: GridHeightfield, expected: HeightfieldReference, query: Vector3,
                             policy: HeightfieldQueryPolicy, work: inout CollisionWork) throws(HeightfieldError) -> HeightfieldPoint
}
