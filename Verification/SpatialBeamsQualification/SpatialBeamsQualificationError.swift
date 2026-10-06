import SwiftMechanics

public enum SpatialBeamsQualificationError: Error, Sendable {
    case assertion(String)
    case unsupportedNativePlatform
    case producer(SpatialBeamError)
    case core(CoreError)
    case model(ModelError)
    case numerical(NumericalError)
}
