#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct SealedLiquidEvaluator: SealedLiquidEvaluating {
    public init() {}
    public func evaluate(law: SealedLiquidLaw, stroke: Double, work: inout ActuationWork) throws(ActuationError) -> SealedLiquidResponse {
        try work.reserve(scalars: 20); try work.charge(64)
        guard stroke.isFinite else { throw .invalidInput }
        guard stroke >= law.minimumStroke, stroke <= law.maximumStroke else { throw .outsideDomain }
        let dv = try finite(law.area * stroke)
        let volume = try finite(law.referenceVolume + dv)
        let y = try finite(dv / law.referenceVolume)
        guard volume > 0, y > -1 else { throw .outsideDomain }
        let logarithm = try finite(log1p(y))
        let pressure = try finite(law.referencePressure - law.bulkModulus * logarithm)
        guard pressure > 0 else { throw .outsideDomain }
        let force = try finite(law.area * (pressure - law.ambientPressure))
        let tangent = try finite(-law.bulkModulus * law.area / volume * law.area)
        // Integral log(1+y) dy is evaluated without near-zero cancellation.
        let dimensionless: Double
        if abs(y) < 0.125 {
            var term = y * y / 2, sum = term
            for n in 2..<18 { term *= -y * Double(n - 1) / Double(n + 1); sum += term }
            dimensionless = sum
        } else { dimensionless = (1 + y) * logarithm - y }
        let elastic = try finite(law.bulkModulus * law.referenceVolume * dimensionless)
        let potential = try finite(elastic + (law.ambientPressure - law.referencePressure) * dv)
        try work.charge(0)
        return SealedLiquidResponse(stroke: stroke, volume: volume, pressure: pressure, force: force,
                                    forceDerivative: tangent, potentialEnergy: potential)
    }
    private func finite(_ value: Double) throws(ActuationError) -> Double {
        guard value.isFinite else { throw .nonfiniteResult }; return value
    }
}
