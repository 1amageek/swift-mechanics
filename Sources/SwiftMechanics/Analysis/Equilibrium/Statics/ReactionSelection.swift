public enum ReactionSelection: Sendable {
    case requireUnique
    /// Original generalized balance is satisfied; dependent row multipliers are zero.
    case independentRowRepresentative
}
