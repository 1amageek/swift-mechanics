public struct TaskSpaceMotion: Sendable {
    public let body: EntityID
    public let bodyLocalPoint: Vector3
    public let axes: [TaskSpaceAxis]
    public let accelerationMetersPerSecondSquared: [Double]
    public let weights: [Double]
    /// Caller-derived posture/feedforward acceleration in original velocity-coordinate order.
    public let secondaryGeneralizedAcceleration: [Double]?
    public init(body: EntityID, bodyLocalPoint: Vector3, axes: [TaskSpaceAxis],
                accelerationMetersPerSecondSquared: [Double], weights: [Double],
                secondaryGeneralizedAcceleration: [Double]? = nil) {
        self.body = body; self.bodyLocalPoint = bodyLocalPoint; self.axes = axes
        self.accelerationMetersPerSecondSquared = accelerationMetersPerSecondSquared
        self.weights = weights; self.secondaryGeneralizedAcceleration = secondaryGeneralizedAcceleration
    }
}
