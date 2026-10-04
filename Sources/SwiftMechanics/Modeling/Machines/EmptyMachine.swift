public struct EmptyMachine: Machine {
    public init() {}
    public var body: Never { fatalError("Primitive machine body must not be evaluated.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {}
}
