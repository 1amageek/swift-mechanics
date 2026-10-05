public struct HydraulicCheckValve: Equatable, Sendable, HydraulicResistanceEvaluating {
    public let conductance: Double
    public let crackingPressure: Double
    public init(conductance: Double, crackingPressure: Double) throws(ActuationError) {
        guard conductance.isFinite, crackingPressure.isFinite, conductance > 0, crackingPressure >= 0 else { throw .invalidLaw }
        self.conductance = conductance; self.crackingPressure = crackingPressure
    }
    public func evaluate(pressureDifference: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicElementResponse {
        try HydraulicArithmetic.preflight(&work)
        guard pressureDifference.isFinite else { throw .invalidInput }
        let flow = pressureDifference > crackingPressure
            ? try HydraulicArithmetic.finite(conductance * (pressureDifference - crackingPressure)) : 0
        let loss = try HydraulicArithmetic.finite(pressureDifference * flow)
        try work.charge(0)
        return try HydraulicElementResponse(pressure: pressureDifference, flow: flow, loss: loss)
    }
}
