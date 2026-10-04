public protocol PlanarTreeReactionRecovering: Sendable {
    func recover(_ system: PhysicalRigidDynamicsSystem, acceleration: [Double], topology: TreeReactionTopology,
                 outputFrame: EntityID, policy: TreeReactionPolicy, loadWork: inout LoadWork,
                 work: inout NumericalWork) throws(ReactionPathError) -> PlanarTreeReactionReport
}
