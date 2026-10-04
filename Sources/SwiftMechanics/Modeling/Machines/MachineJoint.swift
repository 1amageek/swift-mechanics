public struct MachineJoint: Machine {
    public let record: MechanicalJoint
    public let parent: MachineEntityReference
    public let child: MachineEntityReference
    public init(_ record: MechanicalJoint, parent: MachineEntityReference? = nil, child: MachineEntityReference? = nil) {
        self.record = record
        self.parent = parent ?? .local(record.record.parentBody)
        self.child = child ?? .local(record.record.childBody)
    }
    public var body: Never { fatalError("Joint-record lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.append(record, parent: parent, child: child)
    }
}
