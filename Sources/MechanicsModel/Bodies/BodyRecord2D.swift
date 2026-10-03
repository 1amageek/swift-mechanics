public struct BodyRecord2D: Equatable, Sendable {
    public let id: EntityID
    public let frame: EntityID
    public let mode: BodyMotionMode
    public let bodyToWorld: PlanarPose
    public let representations: BodyRepresentations
    public let inertia: InertialRepresentation2D?

    public init(id: EntityID, frame: EntityID, mode: BodyMotionMode, bodyToWorld: PlanarPose,
                representations: BodyRepresentations, inertia: InertialRepresentation2D?) throws(ModelError) {
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
