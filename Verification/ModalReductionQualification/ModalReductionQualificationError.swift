import SwiftMechanics
public enum ModalReductionQualificationError: Error, Sendable {
    case unsupportedOperatingSystem(requiredMacOSMajor: Int)
    case assertion(String)
    case modal(ModalReductionError), field(FieldOutputError), structural(StructuralError)
    case flexible(FlexibleError), material(MaterialError), model(ModelError)
    case core(CoreError), numerical(NumericalError)
}
