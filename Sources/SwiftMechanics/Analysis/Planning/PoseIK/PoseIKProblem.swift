public struct PoseIKProblem: Sendable {
    public let identity: String
    public let tree: KinematicTree
    public let layout: ConstraintCoordinateLayout
    public let worldFrame: EntityID
    public let time: Double
    public let initialPositions: [Double]
    public let referencePositions: [Double]
    public let minimumPositions: [Double]
    public let maximumPositions: [Double]
    public let tasks: [PoseIKTask]
    public let loops: QuadraticConstraintSystem?
    public let branch: PoseIKBranch

    /// Admission is performed by the solve operation under its explicit work budget.
    public init(identity: String, tree: KinematicTree, layout: ConstraintCoordinateLayout,
                worldFrame: EntityID, time: Double, initialPositions: [Double], referencePositions: [Double],
                minimumPositions: [Double], maximumPositions: [Double], tasks: [PoseIKTask],
                loops: QuadraticConstraintSystem? = nil, branch: PoseIKBranch) {
        self.identity = identity; self.tree = tree; self.layout = layout; self.worldFrame = worldFrame
        self.time = time; self.initialPositions = initialPositions; self.referencePositions = referencePositions
        self.minimumPositions = minimumPositions; self.maximumPositions = maximumPositions
        self.tasks = tasks; self.loops = loops; self.branch = branch
    }
}
