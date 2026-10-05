public struct LaminarHydraulicResistance: Equatable, Sendable, HydraulicResistanceEvaluating {
    public let resistance: Double
    public init(resistance: Double) throws(ActuationError) {
        guard resistance.isFinite, resistance > 0 else { throw .invalidLaw }
        self.resistance = resistance
    }
    public func evaluate(pressureDifference: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicElementResponse {
        try HydraulicArithmetic.preflight(&work)
        guard pressureDifference.isFinite else { throw .invalidInput }
        let flow = try HydraulicArithmetic.finite(pressureDifference / resistance)
        let loss = try HydraulicArithmetic.finite(pressureDifference * flow)
        try work.charge(0)
        return try HydraulicElementResponse(pressure: pressureDifference, flow: flow, loss: loss)
    }
}
