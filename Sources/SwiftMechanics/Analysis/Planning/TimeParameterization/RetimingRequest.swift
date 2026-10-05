public struct RetimingRequest: Sendable {
    public let source: RetimingSource
    public let pathID: String
    public let sourceRevision: UInt64
    public let originTime: Double
    public let waypoints: [[Double]]
    public let limits: [RetimingCoordinateLimits]
    public init(source: RetimingSource, pathID: String, sourceRevision: UInt64,
                originTime: Double, waypoints: [[Double]], limits: [RetimingCoordinateLimits]) {
        self.source = source; self.pathID = pathID; self.sourceRevision = sourceRevision
        self.originTime = originTime; self.waypoints = waypoints; self.limits = limits
    }
}
