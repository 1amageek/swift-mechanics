public struct MachineBody: Machine {
    public let record: MechanicalBody
    public init(_ record: MechanicalBody) { self.record = record }
    public init(_ record: BodyRecord3D) { self.record = .spatial(record) }
    public init(_ record: BodyRecord2D) { self.record = .planar(record) }
    public var body: Never { fatalError("Body-record lowering must not evaluate body.") }
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        try context.append(record)
    }
}
