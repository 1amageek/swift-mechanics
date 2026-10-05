/// A scalar joint-coordinate passive law with the supplier's explicit SI domain.
public struct JointSpringDamper: Machine {
    public let id: EntityID
    public let termID: UInt64
    public let joint: MachineEntityReference
    public let law: PolynomialSpringDamper
    public init(id: EntityID, termID: UInt64, joint: MachineEntityReference, law: PolynomialSpringDamper) {
        self.id = id; self.termID = termID; self.joint = joint; self.law = law
    }
    public var body: Never { fatalError("Joint passive law lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This callable law binds one scalar joint chart.
    // Structural system compilation consumes it; point/frame spring attachment, general
    // charts and behavioral qualification are required before broader success is claimed.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        guard id.kind == .load else { throw .invalidBody(.identityKindMismatch) }
        let reference = try context.resolve(joint)
        guard reference.kind == .joint else { throw .invalidJoint(.identityKindMismatch) }
        let absolute = try context.reserveStructuralPhysics(id, references: [reference])
        context.structuralPassiveDrafts.append((absolute, termID, reference, law))
    }
}
