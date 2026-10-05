/// A local parent-body mount (or a root world placement), composed exactly once.
public struct PlacedMachine<Content: Machine>: Machine {
    public let placement: RigidTransform
    public let content: Content
    public init(_ content: Content, placement: RigidTransform) {
        self.content = content; self.placement = placement
    }
    public var body: Never { fatalError("Placement lowering must not evaluate body.") }

    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        guard context.structuralEnabled else {
            throw .compilation(.one(.unsupportedCapability, .input,
                message: "Structural placement requires StructuralMachineDefinition."))
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Placement between a nested joint and its endpoint
        // reaches this branch. Child-anchor placement is explicit; generalized attachment
        // modifiers must be designed and qualified before this ordering can be supported.
        guard context.structuralChildToWorld == nil else {
            throw .compilation(.one(.unsupportedCapability, .input,
                message: "Place the joint parent mount, or supply its child anchor explicitly."))
        }
        let previous = context.structuralPlacement
        defer { context.structuralPlacement = previous }
        do { context.structuralPlacement = try previous.composed(with: placement) }
        catch {
            throw .compilation(.one(.invalidInput, .input,
                message: "Structural placement composition is nonfinite or invalid."))
        }
        try context.lower(content)
    }
}

extension Machine {
    public func placed(at placement: RigidTransform) -> PlacedMachine<Self> {
        PlacedMachine(self, placement: placement)
    }
}
