public protocol TreeKinematicsComputing: Sendable {
    func evaluate(_ tree: KinematicTree, state: KinematicState, policy: JointEvaluationPolicy) throws -> KinematicSnapshot
}
