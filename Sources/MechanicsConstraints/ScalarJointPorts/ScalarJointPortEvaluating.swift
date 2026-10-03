import MechanicsJoints
import MechanicsNumerics

public protocol ScalarJointPortEvaluating: Sendable {
    func passive(_ manifold: JointManifold, position: Double, velocity: Double, law: ScalarJointLaw, wrap: JointWrapPolicy,
                 policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ScalarJointResponse
    func limits(_ manifold: JointManifold, position: Double, velocity: Double, lower: Double, upper: Double,
                mode: JointLimitMode, impact: JointImpactPolicy, wrap: JointWrapPolicy,
                policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ScalarJointLimitResponse
}
