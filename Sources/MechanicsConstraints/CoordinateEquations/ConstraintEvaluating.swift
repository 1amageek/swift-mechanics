import MechanicsNumerics

public protocol ConstraintEvaluating: Sendable {
    func evaluate(_ system: QuadraticConstraintSystem, position: [Double], velocity: [Double], time: Double,
                  policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> ConstraintEvaluation
}
