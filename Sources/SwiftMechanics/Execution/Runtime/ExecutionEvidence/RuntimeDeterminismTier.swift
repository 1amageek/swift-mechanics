public enum RuntimeDeterminismTier: Equatable, Sendable {
    case sameBuildReplay, numericalCrossPlatformEquivalence, bitwisePortability
}
