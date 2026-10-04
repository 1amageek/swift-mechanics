public struct MachineInstance<Content: Machine>: Machine {
    public let id: String
    public let content: Content
    public init(id: String, @MachineBuilder content: () -> Content) { self.id = id; self.content = content() }
    public var body: Never { fatalError("Scoped lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.enterInstance(id)
        defer { context.leaveInstance() }
        try context.lower(content)
    }
}
