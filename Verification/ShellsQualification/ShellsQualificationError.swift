import SwiftMechanics

public enum ShellsQualificationError: Error, Sendable {
    case unsupportedNativePlatform
    case assertion(String)
    case producer(ShellError)
    case core(CoreError)
    case model(ModelError)
    case material(MaterialError)
    case numerical(NumericalError)
}
