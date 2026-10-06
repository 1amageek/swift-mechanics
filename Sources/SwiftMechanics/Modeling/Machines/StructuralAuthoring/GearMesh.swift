/// An ideal signed gear-coordinate relation; tooth contact is a separate physical model.
public struct GearMesh: Machine {
    public let id: EntityID
    public let rowID: UInt64
    public let first: MachineEntityReference
    public let second: MachineEntityReference
    public let firstTeeth: UInt32
    public let secondTeeth: UInt32
    public let phaseRadians: Double
    public let phaseScaleRadians: Double
    public let internalMesh: Bool

    public init(id: EntityID, rowID: UInt64, first: MachineEntityReference, second: MachineEntityReference,
                firstTeeth: UInt32, secondTeeth: UInt32, phaseRadians: Double,
                phaseScaleRadians: Double, internalMesh: Bool) {
        self.id = id; self.rowID = rowID; self.first = first; self.second = second
        self.firstTeeth = firstTeeth; self.secondTeeth = secondTeeth
        self.phaseRadians = phaseRadians; self.phaseScaleRadians = phaseScaleRadians
        self.internalMesh = internalMesh
    }
    public var body: Never { fatalError("Gear relation lowering must not evaluate body.") }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This declaration is an ideal fixed-support scalar
    // relation. Structural system compilation consumes it; moving supports, tooth geometry
    // and the source-only equation composition require their own qualified implementation.
    public func _makeDefinition(into context: inout MachineDefinitionContext) throws(MachineDefinitionFailure) {
        guard id.kind == .load, firstTeeth > 0, secondTeeth > 0,
              phaseRadians.isFinite, phaseScaleRadians.isFinite, phaseScaleRadians > 0 else {
            throw .compilation(.one(.invalidInput, .input, records: [id],
                message: "Ideal gear declaration requires a load identity and finite positive physical inputs."))
        }
        let a = try context.resolve(first), b = try context.resolve(second)
        guard a.kind == .joint, b.kind == .joint, a != b else { throw .invalidJoint(.identityKindMismatch) }
        let absolute = try context.reserveStructuralPhysics(id, references: [a, b])
        context.structuralGearDrafts.append((absolute, rowID, a, b, firstTeeth, secondTeeth,
            phaseRadians, phaseScaleRadians, internalMesh))
    }
}
