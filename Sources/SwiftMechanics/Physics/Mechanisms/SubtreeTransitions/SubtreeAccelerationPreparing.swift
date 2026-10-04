public protocol SubtreeAccelerationPreparing: Sendable {
    func prepare(_ release: SubtreeRelease, gravity: AffineGravity?, bodyWrenches: [BodyWrenchContribution],
                 generalizedForces: [GeneralizedForceContribution], drive: [Double], admission: DynamicsAdmission,
                 policy: DynamicsSolvePolicy, work: inout NumericalWork, loadWork: inout LoadWork) throws(TopologyReleaseFailure) -> ReconciledSubtreeRelease
}
