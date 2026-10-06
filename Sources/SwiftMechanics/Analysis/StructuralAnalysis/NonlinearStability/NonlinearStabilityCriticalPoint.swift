public struct NonlinearStabilityCriticalPoint: Sendable {
    /// Local simple-zero evidence; secondary branch existence is not inferred from orthogonality alone.
    public enum Kind: Sendable { case limitPointCandidate, bifurcationCandidate }
    public let point: NonlinearStabilityPoint
    public let kind: Kind
    public let bracketWidth: Double
    public let normalizedLoadProjection: Double
    public let iterations: Int
    public let work: NumericalWork
}
