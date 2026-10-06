public struct TriangleMesh: Sendable {
    public let geometry: TriangleMeshIdentity
    public let pose: RigidTransform
    internal let nodes: [TriangleMeshNode]

    public init(colliderID: EntityID, bodyID: EntityID, frameID: EntityID,
                geometryRevision: UInt64, frameRevision: UInt64, vertices: [Vector3],
                faces: [TriangleMeshFace], distancePolicy: TriangleMeshDistancePolicy,
                representations: BodyRepresentations, expectedSourceRevision: UInt64,
                pose: RigidTransform, work: inout CollisionWork) throws(TriangleMeshError) {
        try TriangleMeshMath.charge(128, &work)
        guard colliderID.kind == .collider, bodyID.kind == .body, frameID.kind == .frame else {
            throw .collision(.invalidIdentity)
        }
        let representation: GeometryRepresentation
        do { representation = try representations.requiring(.collisionGeometry) }
        catch { throw .collision(.model(error)) }
        guard representation.provenance.revision == expectedSourceRevision else { throw .collision(.staleGeometry) }
        try TriangleMeshKernel.validate(vertices, faces, distancePolicy, &work)
        geometry = TriangleMeshIdentity(colliderID: colliderID, bodyID: bodyID, frameID: frameID,
            geometryRevision: geometryRevision, frameRevision: frameRevision, representation: representation,
            vertices: vertices, faces: faces, distancePolicy: distancePolicy)
        self.pose = pose
        nodes = try TriangleMeshKernel.build(vertices, faces, &work)
    }

    public func moved(to pose: RigidTransform) -> TriangleMesh {
        TriangleMesh(geometry: geometry, pose: pose, nodes: nodes)
    }

    public func refitted(vertices: [Vector3], representation: GeometryRepresentation,
                         expectedSourceRevision: UInt64, geometryRevision: UInt64,
                         work: inout CollisionWork) throws(TriangleMeshError) -> TriangleMesh {
        try TriangleMeshMath.charge(128, &work)
        guard vertices.count == geometry.vertices.count, representation.kind == .collisionGeometry,
              representation.provenance.source == geometry.representation.provenance.source,
              representation.provenance.revision == expectedSourceRevision,
              expectedSourceRevision > geometry.representation.provenance.revision,
              geometryRevision > geometry.geometryRevision else { throw .collision(.staleGeometry) }
        try TriangleMeshKernel.validate(vertices, geometry.faces, geometry.distancePolicy, &work)
        let identity = TriangleMeshIdentity(colliderID: geometry.colliderID, bodyID: geometry.bodyID,
            frameID: geometry.frameID, geometryRevision: geometryRevision, frameRevision: geometry.frameRevision,
            representation: representation, vertices: vertices, faces: geometry.faces, distancePolicy: geometry.distancePolicy)
        let updated = try TriangleMeshKernel.refit(nodes, vertices, geometry.faces, &work)
        return TriangleMesh(geometry: identity, pose: pose, nodes: updated)
    }

    private init(geometry: TriangleMeshIdentity, pose: RigidTransform, nodes: [TriangleMeshNode]) {
        self.geometry = geometry; self.pose = pose; self.nodes = nodes
    }
}
