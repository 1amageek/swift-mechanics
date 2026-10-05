public enum ConvexWitnessDegeneracy: Equatable, Sendable {
    case regular
    /// Original primal/dual bounds admit a contact band, without an exact-zero claim.
    case numericalTouching
    /// Current EPA faces have equal minimum distances within the caller's length tolerance.
    case equidistantPolytopeFaces(count: Int)
}
