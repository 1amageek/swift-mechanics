public enum SpatialBeamStressRequest: Equatable, Sendable {
    case axialNormal
    // FIXME(INCOMPLETE_IMPLEMENTATION): A/J/I/shear factors do not identify section stress distributions.
    // SpatialBeamEvaluating.field rejects this selection until a section warping/distribution
    // supplier and actual resolved-stress path are implemented and qualified.
    case resolvedSection
}
