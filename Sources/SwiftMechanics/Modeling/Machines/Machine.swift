public protocol Machine: Sendable {
    associatedtype Body: Machine
    @MachineBuilder var body: Body { get }
    func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure)
}

extension Machine {
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.lower(body)
    }
}

extension Never: Machine {
    public var body: Never { fatalError("Never has no value or machine body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        switch self {}
    }
}
