public protocol PlanarClosedLoopReactionRecovering: Sendable {
    func recover(_ input: PlanarClosedLoopReactionInput, outputFrame: EntityID, policy: ClosedLoopReactionPolicy,
                 loadWork: inout LoadWork, work: inout NumericalWork) throws(ClosedLoopReactionError) -> PlanarClosedLoopReactionReport
}
