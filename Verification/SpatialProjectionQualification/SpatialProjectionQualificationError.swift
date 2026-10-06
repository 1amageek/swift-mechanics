public enum SpatialProjectionQualificationError: Error, Sendable {
    case assertion(String)
    case unexpectedSuccess(String)
    case unsupportedOperatingSystem
}
