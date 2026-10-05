import SwiftMechanics

public enum GeometryParametersQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(GeometryParameterError)
}
