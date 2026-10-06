import SwiftMechanics

public enum DiscreteCablesQualificationError: Error, Sendable {
    case assertion(String)
    case producer(CableError)
    case core(CoreError)
    case model(ModelError)
    case material(MaterialError)
    case numerical(NumericalError)
}
