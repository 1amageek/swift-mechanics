public struct ArrayMachine<Content: Machine>: Machine {
    public let elements: [Content]
    public init(_ elements: [Content]) { self.elements = elements }
    public var body: Never { fatalError("Composite lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        for element in elements { try context.lower(element) }
    }
}
