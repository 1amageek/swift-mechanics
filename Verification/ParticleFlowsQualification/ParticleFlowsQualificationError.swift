public enum ParticleFlowsQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
}
