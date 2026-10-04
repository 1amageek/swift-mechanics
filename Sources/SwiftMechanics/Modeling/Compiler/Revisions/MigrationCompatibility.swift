public enum MigrationCompatibility: Equatable, Sendable {
    case preservesCoordinates, requiresReset
}
