
public struct CollisionProxy: Equatable, Sendable {
    public let geometry: CollisionGeometryIdentity
    public let pose: RigidTransform
    public let filter: ColliderFilter

    public init(colliderID: EntityID, bodyID: EntityID, frameID: EntityID,
                geometryRevision: UInt64, frameRevision: UInt64, shape: CollisionShape,
                margin: Double, representations: BodyRepresentations, expectedSourceRevision: UInt64,
                resolution: CollisionResolution, pose: RigidTransform, filter: ColliderFilter) throws(CollisionError) {
        guard colliderID.kind == .collider, bodyID.kind == .body, frameID.kind == .frame else { throw .invalidIdentity }
        try shape.validate(); try resolution.validate()
        guard margin.isFinite, margin >= 0 else { throw .invalidShape }
        let representation: GeometryRepresentation
        do { representation = try representations.requiring(.collisionGeometry) } catch { throw .model(error) }
        guard representation.provenance.revision == expectedSourceRevision else { throw .staleGeometry }
        geometry = CollisionGeometryIdentity(colliderID: colliderID, bodyID: bodyID, frameID: frameID,
            geometryRevision: geometryRevision, frameRevision: frameRevision, shape: shape, margin: margin,
            representation: representation, resolution: resolution)
        self.pose = pose; self.filter = filter
    }

    public func moved(to pose: RigidTransform) -> CollisionProxy {
        CollisionProxy(geometry: geometry, pose: pose, filter: filter)
    }

    private init(geometry: CollisionGeometryIdentity, pose: RigidTransform, filter: ColliderFilter) {
        self.geometry = geometry; self.pose = pose; self.filter = filter
    }
}
