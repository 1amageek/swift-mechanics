import SwiftMechanics

public enum LinearQuadraticQualificationError: Error, Sendable {
    case platformUnavailable
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(LinearQuadraticFailure)
}
