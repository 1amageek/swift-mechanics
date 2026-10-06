public struct PoseIKFailure: Error, Sendable {
    public let identity: String
    public let cause: PoseIKError
    /// Nil when the remaining budget cannot materialize a truthful final SI position record.
    public let lastPositions: [Double]?
    public let original: PoseIKEvidence?
    /// Why a terminal original witness is unavailable; never replace this with zero residuals.
    public let originalUnavailable: PoseIKError?
    public let work: NumericalWork
}
