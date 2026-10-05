public struct URDFCollisionBinding: URDFCollisionConfiguring {
    public let body: EntityID
    public let collider: EntityID
    public let shape: CollisionShape
    public let shapeToBody: RigidTransform
    public let representation: GeometryRepresentation
    public let stamp: ModelStamp
    public let worldFrame: EntityID
    internal init(body: EntityID, collider: EntityID, shape: CollisionShape, shapeToBody: RigidTransform,
                  representation: GeometryRepresentation, stamp: ModelStamp, worldFrame: EntityID) {
        self.body = body; self.collider = collider; self.shape = shape; self.shapeToBody = shapeToBody
        self.representation = representation; self.stamp = stamp; self.worldFrame = worldFrame
    }

    /// Evaluates this model's validated state before constructing the actual analytic query configuration.
    public func proxy(state: CompiledKinematicState, model: CompiledMechanicalModel, frameRevision: UInt64,
                      margin: Double, filter: ColliderFilter, work: inout URDFWork) throws(URDFFailure) -> CollisionProxy {
        do {
            try work.charge(1)
            try model.validating(stamp: stamp)
            guard model.tree.worldFrame == worldFrame else { throw URDFFailure(.invalid("collision world frame")) }
            let snapshot = try model.evaluate(state)
            try work.charge(40)
            let pose = try snapshot.body(body).motion.pose.composed(with: shapeToBody)
            return try CollisionProxy(colliderID: collider, bodyID: body, frameID: worldFrame,
                geometryRevision: stamp.revision, frameRevision: frameRevision, shape: shape, margin: margin,
                representations: BodyRepresentations(collisionGeometry: representation),
                expectedSourceRevision: representation.provenance.revision, resolution: .analytic, pose: pose, filter: filter)
        } catch let error as URDFFailure { throw error }
        catch let error as CompilationFailure { throw URDFFailure(.compilation(error)) }
        catch let error as CoreError { throw URDFFailure(.core(error)) }
        catch let error as JointError { throw URDFFailure(.joint(error)) }
        catch let error as ModelError { throw URDFFailure(.model(error)) }
        catch let error as CollisionError { throw URDFFailure(.collision(error)) }
        catch { throw URDFFailure(.unexpectedProducer) }
    }
}
