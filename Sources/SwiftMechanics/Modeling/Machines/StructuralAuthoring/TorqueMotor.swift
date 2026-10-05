/// Memoryless constant relative joint torque; the declared joint supplies rotor/stator roles.
public struct TorqueMotor: Machine {
    public let id: EntityID
    public let joint: MachineEntityReference
    public let torqueNm: Double
    public init(id: EntityID, joint: MachineEntityReference, torqueNm: Double) {
        self.id = id; self.joint = joint; self.torqueNm = torqueNm
    }
    public var body: Never { fatalError("Constant torque lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): Structural compilation consumes a constant ideal
    // torque source bound to an actual revolute joint. Electrical/servo laws and mutable
    // input/continuation require the actuation/runtime owners before those domains succeed.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        guard id.kind == .actuator, torqueNm.isFinite else {
            throw .compilation(.one(.invalidInput, .input, records: [id],
                message: "Constant torque declaration needs an actuator identity and finite torque."))
        }
        let reference = try context.resolve(joint)
        guard reference.kind == .joint else { throw .invalidJoint(.identityKindMismatch) }
        let absolute = try context.reserveStructuralPhysics(id, references: [reference])
        context.structuralMotorDrafts.append((absolute, reference, torqueNm))
    }
}
