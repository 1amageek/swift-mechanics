public struct TrussContinuation: Sendable {
    public let model: NonlinearTruss
    public let points: [TrussPoint]
    /// Displacement control of the symmetric vertical branch only.
    public let descending: Bool
}
