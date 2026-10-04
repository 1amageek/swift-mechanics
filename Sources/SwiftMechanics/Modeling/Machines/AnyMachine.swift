public struct AnyMachine: Machine {
    private let storage: any MachineStorage
    public init<Content: Machine>(_ content: Content) { storage = ConcreteMachineStorage(content) }
    public var body: Never { fatalError("Erased lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try storage.lower(into: &context)
    }
}

private protocol MachineStorage: Sendable {
    func lower(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure)
}

private final class ConcreteMachineStorage<Content: Machine>: MachineStorage {
    let content: Content
    init(_ content: Content) { self.content = content }
    func lower(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.lower(content)
    }
}
