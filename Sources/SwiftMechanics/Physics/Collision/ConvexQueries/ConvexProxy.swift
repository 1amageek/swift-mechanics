public struct ConvexProxy: Equatable, Sendable {
    public let geometry: ConvexGeometryIdentity
    public let pose: RigidTransform
    internal let analyticAdapter: CollisionProxy?

    public init(colliderID: EntityID, bodyID: EntityID, frameID: EntityID,
                geometryRevision: UInt64, frameRevision: UInt64, shape: ConvexShape,
                margin: Double, representations: BodyRepresentations, expectedSourceRevision: UInt64,
                resolution: CollisionResolution, pose: RigidTransform,
                work: inout CollisionWork) throws(ConvexCollisionError) {
        guard colliderID.kind == .collider, bodyID.kind == .body, frameID.kind == .frame else {
            throw .collision(.invalidIdentity)
        }
        try shape.validate(work: &work)
        guard margin.isFinite, margin >= 0 else { throw .invalidShape }
        try ConvexMath.collision { () throws(CollisionError) in try resolution.validate() }
        let representation: GeometryRepresentation
        do { representation = try representations.requiring(.collisionGeometry) }
        catch { throw .collision(.model(error)) }
        guard representation.provenance.revision == expectedSourceRevision else { throw .collision(.staleGeometry) }
        geometry = ConvexGeometryIdentity(colliderID: colliderID, bodyID: bodyID, frameID: frameID,
            geometryRevision: geometryRevision, frameRevision: frameRevision, shape: shape,
            margin: margin, representation: representation, resolution: resolution)
        self.pose = pose
        analyticAdapter = nil
    }

    public init(adapting proxy: CollisionProxy) throws(ConvexCollisionError) {
        let shape: ConvexShape
        switch proxy.geometry.shape {
        case .sphere(let radius): shape = .sphere(radius: radius)
        case .box(let halfExtents): shape = .box(halfExtents: halfExtents)
        case .halfSpace: throw .unsupportedShape
        }
        let g = proxy.geometry
        geometry = ConvexGeometryIdentity(colliderID: g.colliderID, bodyID: g.bodyID, frameID: g.frameID,
            geometryRevision: g.geometryRevision, frameRevision: g.frameRevision, shape: shape,
            margin: g.margin, representation: g.representation, resolution: g.resolution)
        pose = proxy.pose
        analyticAdapter = proxy
    }

    public func moved(to pose: RigidTransform) -> ConvexProxy {
        ConvexProxy(geometry: geometry, pose: pose, analyticAdapter: analyticAdapter?.moved(to: pose))
    }

    private init(geometry: ConvexGeometryIdentity, pose: RigidTransform, analyticAdapter: CollisionProxy?) {
        self.geometry = geometry; self.pose = pose; self.analyticAdapter = analyticAdapter
    }
}
