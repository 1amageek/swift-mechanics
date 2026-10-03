import MechanicsNumerics
import MechanicsConstraints
import MechanicsDynamics

public protocol MechanismSleepEvaluating: Sendable {
    func evaluate(_ system:RigidDynamicsSystem,sample:VelocityConstraintSample,wakeCoordinateIDs:[UInt64],policy:MechanismSleepPolicy,
                  work:inout NumericalWork) throws(MechanismError) -> MechanismSleepDecision
}
