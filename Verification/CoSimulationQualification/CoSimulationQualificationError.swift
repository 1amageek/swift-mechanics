public enum CoSimulationQualificationError: Error, Sendable {
    case unsupportedPlatform
    case oracle(String)
    case unexpectedSuccess(String)
    case wrongFailure(String)
}
