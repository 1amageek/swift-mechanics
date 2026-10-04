public protocol PlanarPrescribedRootReactionRecovering: Sendable {
    func recover(_ input: PlanarPrescribedRootReactionInput, outputFrame: EntityID,
                 policy: PlanarPrescribedRootReactionPolicy, loadWork: inout LoadWork,
                 work: inout NumericalWork) throws(PlanarPrescribedRootReactionError) -> PlanarPrescribedRootReactionReport
}
