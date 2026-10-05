import SwiftMechanics

public enum ArticulatedDynamicsQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(String)
    case unexpectedArticulatedFailure(ArticulatedDynamicsFailure)
}
