public struct HydraulicInertance: Equatable, Sendable, HydraulicInertanceEvaluating {
    public let inertance: Double
    public init(inertance: Double) throws(ActuationError) {
        guard inertance.isFinite, inertance > 0 else { throw .invalidLaw }
        self.inertance = inertance
    }
    public func evaluate(volumeFlow: Double, flowAcceleration: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicElementResponse {
        try HydraulicArithmetic.preflight(&work)
        guard volumeFlow.isFinite, flowAcceleration.isFinite else { throw .invalidInput }
        let pressure = try HydraulicArithmetic.finite(inertance * flowAcceleration)
        let energy = try HydraulicArithmetic.finite(0.5 * inertance * volumeFlow * volumeFlow)
        let rate = try HydraulicArithmetic.finite(inertance * volumeFlow * flowAcceleration)
        try work.charge(0)
        return try HydraulicElementResponse(pressure: pressure, flow: volumeFlow, energy: energy, storagePower: rate)
    }
}
