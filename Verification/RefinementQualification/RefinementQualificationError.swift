import SwiftMechanics

public enum RefinementQualificationError: Error, Sendable {
    case assertion(String)
    case producer(RefinementError)
    case core(CoreError)
    case flexible(FlexibleError)
    case material(MaterialError)
    case model(ModelError)
    case numerical(NumericalError)
}
