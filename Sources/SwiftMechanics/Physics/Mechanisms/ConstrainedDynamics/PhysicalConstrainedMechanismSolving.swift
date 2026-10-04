public protocol PhysicalConstrainedMechanismSolving: Sendable {
    func acceleration(_ system: PhysicalRigidDynamicsSystem, sample: VelocityConstraintSample, drive: [Double],
                      policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                      rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion
    func reconcileVelocity(_ system: PhysicalRigidDynamicsSystem, sample: VelocityConstraintSample,
                           policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                           rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion
}
