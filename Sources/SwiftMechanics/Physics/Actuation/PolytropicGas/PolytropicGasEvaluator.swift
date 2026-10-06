#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct PolytropicGasEvaluator: PolytropicGasEvaluating {
    public init() {}
    public func evaluate(law: PolytropicGasLaw, stroke: Double, work: inout ActuationWork) throws(ActuationError) -> PolytropicGasResponse {
        try work.reserve(scalars: 20); try work.charge(32)
        guard stroke.isFinite else { throw .invalidInput }
        guard stroke >= law.minimumStroke, stroke <= law.maximumStroke else { throw .outsideDomain }
        let dv = try finite(law.area * stroke)
        let volume = try finite(law.referenceVolume + dv)
        let ratio = try finite(dv / law.referenceVolume)
        guard volume > 0, ratio > -1 else { throw .outsideDomain }
        let logVolume = try finite(log1p(ratio))
        let pressure = try finite(law.referencePressure * exp(-law.exponent * logVolume))
        guard pressure > 0 else { throw .outsideDomain }
        let force = try finite(law.area * (pressure - law.ambientPressure))
        let tangent = try finite(-law.exponent * pressure * law.area / volume * law.area)
        let delta = law.exponent - 1
        let gasPotential: Double
        if delta == 0 { gasPotential = try finite(-law.referencePressure * law.referenceVolume * logVolume) }
        else {
            let z = try finite(-delta * logVolume)
            // expm1(z)/z remains accurate arbitrarily close to the isothermal exponent.
            let exprel = z == 0 ? 1 : expm1(z) / z
            gasPotential = try finite(-law.referencePressure * law.referenceVolume * logVolume * exprel)
        }
        let potential = try finite(gasPotential + law.ambientPressure * dv)
        try work.charge(0)
        return PolytropicGasResponse(stroke: stroke, volume: volume, pressure: pressure, force: force,
                                     forceDerivative: tangent, potentialEnergy: potential)
    }
    private func finite(_ value: Double) throws(ActuationError) -> Double {
        guard value.isFinite else { throw .nonfiniteResult }; return value
    }
}
