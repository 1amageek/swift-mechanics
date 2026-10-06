public struct PoseIKResult: Sendable {
    public let identity: String
    public let source: PoseIKProblem
    public let state: KinematicState
    public let initialPositions: [Double]
    public let referencePositions: [Double]
    public let branch: PoseIKBranch
    /// Equality-query covectors for the reference-distance objective; these are not mechanical forces.
    public let queryMultipliers: [Double]
    public let original: PoseIKEvidence
    public let nonlinear: NonlinearSolution<Double>
    public let work: NumericalWork
}
