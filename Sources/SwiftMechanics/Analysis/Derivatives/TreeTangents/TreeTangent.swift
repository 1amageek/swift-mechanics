public struct TreeTangent: Sendable {
    public let snapshot: KinematicSnapshot
    public let bodies: [BodyTangent]
    /// Row-major body/velocity column layout; geometric motion at each body origin in world frame.
    public let coordinateRate: [Double]
    public let geometricColumns: [SpatialMotion]
    internal let frames: [DifferentialFrame]
    internal let columns: [DifferentialMotion]
    internal let bias: [DifferentialMotion]
}
