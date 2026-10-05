import SwiftMechanics

public enum HexahedraQualificationError: Error, Sendable {
    case assertion(String)
    case producer(HexahedralError)
    case core(CoreError)
    case model(ModelError)
    case material(MaterialError)
    case flexible(FlexibleError)
    case numerical(NumericalError)
    case mutexUnavailable
}
