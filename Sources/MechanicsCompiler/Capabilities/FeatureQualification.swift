public enum FeatureQualification: Equatable, Sendable {
    case descriptorValidated(modelRevision: UInt64)
    case executionUnqualified(reason: String)
}
