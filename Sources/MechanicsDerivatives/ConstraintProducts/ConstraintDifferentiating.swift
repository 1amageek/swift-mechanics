import MechanicsConstraints
import MechanicsNumerics
public protocol ConstraintDifferentiating: Sendable {
    func direction(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                   direction: ConstraintDirection, evaluationPolicy: ConstraintEvaluationPolicy, policy: DerivativePolicy,
                   work: inout NumericalWork) throws(DerivativeError) -> ConstraintTangent
}
