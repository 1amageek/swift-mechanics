public struct LinearHydraulicCompliance: Equatable, Sendable, HydraulicComplianceEvaluating {
    public let compliance: Double
    public init(compliance: Double) throws(ActuationError) {
        guard compliance.isFinite, compliance > 0 else { throw .invalidLaw }
        self.compliance = compliance
    }
    public func evaluate(volumeDisplacement: Double, volumeFlow: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicElementResponse {
        try HydraulicArithmetic.preflight(&work)
        guard volumeDisplacement.isFinite, volumeFlow.isFinite else { throw .invalidInput }
        let pressure = try HydraulicArithmetic.finite(volumeDisplacement / compliance)
        let energy = try HydraulicArithmetic.finite(0.5 * volumeDisplacement * pressure)
        let rate = try HydraulicArithmetic.finite((volumeDisplacement * volumeFlow) / compliance)
        try work.charge(0)
        return try HydraulicElementResponse(pressure: pressure, flow: volumeFlow, energy: energy, storagePower: rate)
    }
}
