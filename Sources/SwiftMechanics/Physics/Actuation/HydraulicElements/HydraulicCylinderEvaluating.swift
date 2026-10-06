public protocol HydraulicCylinderEvaluating: Sendable {
    func evaluate(stroke: Double, velocity: Double, firstPressure: Double, secondPressure: Double,
                  firstFlow: Double, secondFlow: Double, work: inout ActuationWork)
        throws(ActuationError) -> HydraulicCylinderResponse
}
