public struct OptionalMachine<Content: Machine>: Machine {
    public let content: Content?
    public init(_ content: Content?) { self.content = content }
    public var body: Never { fatalError("Composite lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        if let content { try context.lower(content) }
    }
}
