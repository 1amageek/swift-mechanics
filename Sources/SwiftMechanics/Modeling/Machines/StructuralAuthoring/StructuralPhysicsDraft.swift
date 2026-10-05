/// Complete source-bound physical declarations; only the structural lowering owner constructs it.
public struct StructuralPhysicsDraft: Sendable {
    public let descriptor: MechanicalDescriptor
    public let gears: [StructuralGearRelation]
    public let passiveLaws: [StructuralPassiveLaw]
    public let torques: [StructuralConstantTorque]
    internal init(descriptor: MechanicalDescriptor, gears: [StructuralGearRelation],
                  passiveLaws: [StructuralPassiveLaw], torques: [StructuralConstantTorque]) {
        self.descriptor = descriptor; self.gears = gears; self.passiveLaws = passiveLaws; self.torques = torques
    }
}
