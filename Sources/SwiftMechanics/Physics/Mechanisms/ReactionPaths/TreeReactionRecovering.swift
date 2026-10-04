public protocol TreeReactionRecovering: Sendable {
    /// Recovers continuous edge wrenches only after original per-body virtual-work and body balances accept.
    func recover(_ system: RigidDynamicsSystem, acceleration: [Double], topology: TreeReactionTopology,
                 outputFrame: EntityID, policy: TreeReactionPolicy,
                 loadWork: inout LoadWork, work: inout NumericalWork) throws(ReactionPathError) -> TreeReactionReport
}
