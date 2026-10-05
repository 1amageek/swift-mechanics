import SwiftMechanics

public enum JointStopQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(JointStopFailure)
}
