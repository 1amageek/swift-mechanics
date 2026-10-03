import MechanicsNumerics
import MechanicsConstraints
import MechanicsDynamics

public protocol ConstrainedMechanismSolving: Sendable {
    func acceleration(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample, drive: [Double],
                      policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                      rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> ConstrainedMotion
    func reconcileVelocity(_ system: RigidDynamicsSystem, sample: VelocityConstraintSample,
                           policy: MechanismSolvePolicy, work: inout NumericalWork, dynamicsWork: inout NumericalWork,
                           rankWork: inout NumericalWork, linearWork: inout NumericalWork) throws(MechanismError) -> ConstrainedMotion
}
