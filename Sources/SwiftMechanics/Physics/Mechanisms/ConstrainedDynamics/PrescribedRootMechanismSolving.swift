public protocol PrescribedRootMechanismSolving: Sendable {
    func acceleration(_ constraint:PrescribedRootConstraint,drive:[Double],policy:MechanismSolvePolicy,
                      work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,
                      linearWork:inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion
    func reconcileVelocity(_ constraint:PrescribedRootConstraint,policy:MechanismSolvePolicy,
                           work:inout NumericalWork,dynamicsWork:inout NumericalWork,rankWork:inout NumericalWork,
                           linearWork:inout NumericalWork) throws(MechanismError) -> PhysicalConstrainedMotion
}
