import SwiftMechanics

public enum TaskSpaceQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(TaskSpaceFailure)
}
