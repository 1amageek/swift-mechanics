/// Declared body-local proxy geometry, never a supplied world pose or query witness.
public struct ObservationColliderBinding: Equatable, Sendable {
    public let colliderID: EntityID
    public let body: EntityID
    public let geometryRevision: UInt64
    public let shape: CollisionShape
    public let margin: Double
    public let representations: BodyRepresentations
    public let expectedSourceRevision: UInt64
    public let resolution: CollisionResolution
    public let colliderToBody: RigidTransform
    public let filter: ColliderFilter
    public init(colliderID: EntityID, body: EntityID, geometryRevision: UInt64, shape: CollisionShape,
                margin: Double, representations: BodyRepresentations, expectedSourceRevision: UInt64,
                resolution: CollisionResolution, colliderToBody: RigidTransform, filter: ColliderFilter)
        throws(ContactRangeObservationError) {
        guard colliderID.kind == .collider, body.kind == .body, margin.isFinite, margin >= 0 else { throw .invalidInput }
        do throws(CollisionError) { try shape.validate();try resolution.validate() } catch { throw .collision(error) }
        self.colliderID=colliderID;self.body=body;self.geometryRevision=geometryRevision;self.shape=shape
        self.margin=margin;self.representations=representations;self.expectedSourceRevision=expectedSourceRevision
        self.resolution=resolution;self.colliderToBody=colliderToBody;self.filter=filter
    }
}
