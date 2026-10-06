public protocol PoseIKSolving: Sendable {
    func solve(_ problem: PoseIKProblem, policy: PoseIKPolicy) throws(PoseIKFailure) -> PoseIKResult
}
