public struct RigidBody<Content: Machine>: Machine {
    public let id: EntityID
    public let frame: EntityID
    public let mode: BodyMotionMode
    public let placement: RigidBodyPlacement
    public let representations: BodyRepresentations
    public let inertia: InertialRepresentation3D?
    public let content: Content

    public init(id: EntityID, frame: EntityID, mode: BodyMotionMode = .dynamic,
                placement: RigidBodyPlacement, representations: BodyRepresentations,
                inertia: InertialRepresentation3D?, @MachineBuilder content: () -> Content) {
        self.id = id; self.frame = frame; self.mode = mode; self.placement = placement
        self.representations = representations; self.inertia = inertia; self.content = content()
    }

    private init(id: EntityID, frame: EntityID, mode: BodyMotionMode, placement: RigidBodyPlacement,
                 representations: BodyRepresentations, inertia: InertialRepresentation3D?, content: Content) {
        self.id = id; self.frame = frame; self.mode = mode; self.placement = placement
        self.representations = representations; self.inertia = inertia; self.content = content
    }

    public func fixed() -> Self {
        Self(id: id, frame: frame, mode: .static, placement: placement,
             representations: representations, inertia: inertia, content: content)
    }

    public var body: Never { fatalError("Rigid body lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This source-only spatial rigid declaration does not
    // aggregate constituent inertia or lower geometry/laws. StructuralMachineDefinition calls
    // this path; the selected records and legacy regressions require behavioral qualification.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.lowerStructuralBody(self)
    }
}
