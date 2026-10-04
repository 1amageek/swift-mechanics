
public struct BodyRecord3D: Equatable, Sendable {
    public let id: EntityID
    public let frame: EntityID
    public let mode: BodyMotionMode
    public let bodyToWorld: RigidTransform
    public let representations: BodyRepresentations
    public let inertia: InertialRepresentation3D?

    public init(id: EntityID, frame: EntityID, mode: BodyMotionMode, bodyToWorld: RigidTransform,
                representations: BodyRepresentations, inertia: InertialRepresentation3D?) throws(ModelError) {
        guard id.kind == .body, frame.kind == .frame else { throw .identityKindMismatch }
        guard mode != .dynamic || inertia != nil else { throw .missingDynamicInertia }
        self.id = id
        self.frame = frame
        self.mode = mode
        self.bodyToWorld = bodyToWorld
        self.representations = representations
        self.inertia = inertia
    }
}
