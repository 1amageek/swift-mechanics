public struct RetimedPath: Sendable {
    public let source: RetimingSource
    public let pathID: String
    public let sourceRevision: UInt64
    public let worldFrame: EntityID
    public let coordinateLayout: TreeCoordinateLayout
    public let originTime: Double
    public let endTime: Double
    public let waypoints: [[Double]]
    public let limits: [RetimingCoordinateLimits]
    public let segments: [RetimingSegment]
    public let referenceMassMatrix: [Double]
    public let staticEffort: [Double]
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    /// Every waypoint is an explicit zero-velocity, zero-acceleration stop.
    public let stopsAtEveryWaypoint = true
    public let interpolation = "rest-to-rest C2 quintic on straight Euclidean segments"
    public let policy: RetimingPolicy
    internal let retainedScalars: Int
    internal init(request: RetimingRequest, segments: [RetimingSegment], mass: [Double], staticEffort: [Double],
                  policy: RetimingPolicy, retainedScalars: Int, numericalWork: NumericalWork, loadWork: LoadWork) {
        source = request.source; pathID = request.pathID; sourceRevision = request.sourceRevision
        worldFrame = source.tree.worldFrame; coordinateLayout = source.tree.layout
        originTime = request.originTime; endTime = segments[segments.count - 1].endTime
        waypoints = request.waypoints; limits = request.limits; self.segments = segments
        referenceMassMatrix = mass; self.staticEffort = staticEffort
        self.policy = policy; self.retainedScalars = retainedScalars; self.numericalWork = numericalWork; self.loadWork = loadWork
    }
}
