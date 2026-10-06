import SwiftMechanics

public enum TireLawsQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case originalFailure(TireLawError)
}
