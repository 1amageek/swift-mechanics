public struct RetimingCoordinateLimits: Equatable, Sendable {
    /// Prismatic generalized speed (m/s), acceleration (m/s^2), and effort (N).
    public let speed: RetimingInterval
    public let acceleration: RetimingInterval
    public let effort: RetimingInterval
    public init(speed: RetimingInterval, acceleration: RetimingInterval, effort: RetimingInterval) {
        self.speed = speed; self.acceleration = acceleration; self.effort = effort
    }
}
