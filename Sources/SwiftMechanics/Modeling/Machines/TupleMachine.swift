public struct TupleMachine<First: Machine, Second: Machine>: Machine {
    public let first: First
    public let second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public var body: Never { fatalError("Composite lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.lower(first)
        try context.lower(second)
    }
}
