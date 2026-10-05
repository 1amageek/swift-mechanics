/// Focused nested articulation contract used by the concrete physical pair names.
public protocol StructuralJointMachine: Machine where Body == Never {
    associatedtype Content: Machine
    var configuration: StructuralJointConfiguration { get }
    var content: Content { get }
}

extension StructuralJointMachine {
    public var body: Never { fatalError("Structural articulation lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): Nested spatial authoring is source-written only.
    // Named-joint Machine dispatch enters this path; deferred reference collection, closed-loop
    // authoring and original profile behavioral qualification are required for broader success.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.lowerStructuralJoint(configuration, content: content)
    }
}
