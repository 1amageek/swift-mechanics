public protocol ClosedLoopReactionRecovering: Sendable {
    func recover(_ input: ClosedLoopReactionInput, outputFrame: EntityID, policy: ClosedLoopReactionPolicy,
                 loadWork: inout LoadWork, work: inout NumericalWork) throws(ClosedLoopReactionError) -> ClosedLoopReactionReport
}
