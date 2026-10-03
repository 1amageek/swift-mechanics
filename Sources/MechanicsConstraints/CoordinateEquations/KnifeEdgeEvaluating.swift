import MechanicsNumerics

public protocol KnifeEdgeEvaluating: Sendable {
    func evaluate(layout: ConstraintCoordinateLayout, rowID: UInt64, position: [Double], velocity: [Double],
                  policy: ConstraintEvaluationPolicy, work: inout NumericalWork) throws(ConstraintError) -> VelocityConstraintSample
}
