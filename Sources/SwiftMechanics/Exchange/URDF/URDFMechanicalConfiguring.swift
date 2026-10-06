public protocol URDFMechanicalConfiguring: Sendable {
    func dynamicsInput(state: CompiledKinematicState, gravity: AffineGravity?,
                       bodyWrenches: [BodyWrenchContribution], generalizedForces: [GeneralizedForceContribution],
                       work: inout URDFWork) throws(URDFFailure) -> RigidDynamicsInput
}
