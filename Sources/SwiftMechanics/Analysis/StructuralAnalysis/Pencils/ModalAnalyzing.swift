public protocol ModalAnalyzing: Sendable {
    func modes(_ pencil: StructuralPencil, expectedBinding: StructuralBinding, policy: StructuralPolicy,
               work: inout NumericalWork) throws(StructuralError) -> ModalResult
    func dampedModes(_ pencil: StructuralPencil, expectedBinding: StructuralBinding, massDamping: Double, stiffnessDamping: Double,
                     policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> DampedModalResult
    func nonproportionalDampedModes(_ pencil: StructuralPencil, expectedBinding: StructuralBinding,
                                   policy: StructuralPolicy, work: inout NumericalWork) throws(StructuralError) -> DampedModalResult
}
