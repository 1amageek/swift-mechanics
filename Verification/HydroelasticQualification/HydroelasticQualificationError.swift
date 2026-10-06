import SwiftMechanics

public enum HydroelasticQualificationError: Error, Sendable {
    case assertion(String)
    case unsupportedOperatingSystem
    case producer(HydroelasticError)
    case core(CoreError)
    case flexible(FlexibleError)
    case material(MaterialError)
    case numerical(NumericalError)
    case model(ModelError)
}
