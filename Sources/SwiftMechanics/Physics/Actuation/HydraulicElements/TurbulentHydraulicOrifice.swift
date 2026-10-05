#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct TurbulentHydraulicOrifice: Equatable, Sendable, HydraulicResistanceEvaluating {
    public let dischargeCoefficient: Double
    public let area: Double
    public let density: Double
    public init(dischargeCoefficient: Double, area: Double, density: Double) throws(ActuationError) {
        guard dischargeCoefficient.isFinite, area.isFinite, density.isFinite,
              dischargeCoefficient > 0, area > 0, density > 0 else { throw .invalidLaw }
        self.dischargeCoefficient = dischargeCoefficient; self.area = area; self.density = density
    }
    public func evaluate(pressureDifference: Double, work: inout ActuationWork) throws(ActuationError) -> HydraulicElementResponse {
        try HydraulicArithmetic.preflight(&work)
        guard pressureDifference.isFinite else { throw .invalidInput }
        let speed = sqrt(try HydraulicArithmetic.finite(2 * (abs(pressureDifference) / density)))
        let unsignedFlow = try HydraulicArithmetic.finite(dischargeCoefficient * area * speed)
        let flow = pressureDifference < 0 ? -unsignedFlow : unsignedFlow
        let loss = try HydraulicArithmetic.finite(pressureDifference * flow)
        try work.charge(0)
        return try HydraulicElementResponse(pressure: pressureDifference, flow: flow, loss: loss)
    }
}
