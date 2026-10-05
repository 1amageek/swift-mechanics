/// Actual relative joint effort port; rotor/stator roles come from the admitted joint record.
public struct StructuralMotorBinding: Sendable {
    public let declaration: StructuralConstantTorque
    public let rotor: EntityID
    public let stator: EntityID
    public let transfer: AffineTransmission
    internal init(declaration: StructuralConstantTorque, rotor: EntityID, stator: EntityID,
                  transfer: AffineTransmission) {
        self.declaration = declaration; self.rotor = rotor; self.stator = stator; self.transfer = transfer
    }
}
