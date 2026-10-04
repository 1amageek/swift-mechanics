public enum ConditionalMachine<First: Machine, Second: Machine>: Machine {
    case first(First)
    case second(Second)
    public var body: Never { fatalError("Composite lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        switch self {
        case .first(let content): try context.lower(content)
        case .second(let content): try context.lower(content)
        }
    }
}
