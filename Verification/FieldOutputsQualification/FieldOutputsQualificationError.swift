import SwiftMechanics

public enum FieldOutputsQualificationError: Error, Sendable {
    case assertion(String)
    case producer(FieldOutputError)
    case core(CoreError)
    case flexible(FlexibleError)
    case material(MaterialError)
    case model(ModelError)
    case numerical(NumericalError)
}
