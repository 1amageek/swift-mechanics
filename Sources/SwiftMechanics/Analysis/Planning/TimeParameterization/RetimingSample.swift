public struct RetimingSample: Sendable {
    public let sourceID: String
    public let pathID: String
    public let sourceRevision: UInt64
    public let worldFrame: EntityID
    public let coordinateLayout: TreeCoordinateLayout
    public let segment: Int
    public let fraction: Double
    public let state: KinematicState
    public let snapshot: KinematicSnapshot
    public let effort: [Double]
    public let analyticEffort: [Double]
    public let numericalWork: NumericalWork
    public let loadWork: LoadWork
    internal init(path: RetimedPath, segment: Int, fraction: Double, state: KinematicState,
                  snapshot: KinematicSnapshot, effort: [Double], analyticEffort: [Double],
                  numericalWork: NumericalWork, loadWork: LoadWork) {
        sourceID = path.source.sourceID; pathID = path.pathID; sourceRevision = path.sourceRevision
        worldFrame = path.worldFrame; coordinateLayout = path.coordinateLayout
        self.segment = segment; self.fraction = fraction; self.state = state; self.snapshot = snapshot
        self.effort = effort; self.analyticEffort = analyticEffort; self.numericalWork = numericalWork; self.loadWork = loadWork
    }
}
