import SwiftMechanics

public enum InertialParametersQualificationError: Error, Sendable {
    case assertion(String)
    case unsupportedPlatform(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(InertialParameterError)
}
