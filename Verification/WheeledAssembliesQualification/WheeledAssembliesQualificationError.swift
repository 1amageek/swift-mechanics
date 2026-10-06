import SwiftMechanics

public enum WheeledAssembliesQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unexpectedFailure(String)
    case originalFailure(WheeledAssemblyFailure)
}
