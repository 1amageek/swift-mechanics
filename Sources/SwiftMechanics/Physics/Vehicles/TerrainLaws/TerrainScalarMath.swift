#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("No admitted terrain scalar mathematics platform is available.")
#endif

/// Soil-specific scalar operations; no supplier source or shared state is modified.
internal enum TerrainScalarMath {
    static func power(_ x: Double, _ n: Double) throws(TerrainLawError) -> Double {
        try terrainFinite(pow(x, n))
    }
    /// Mean of z^n over a positive interval, without subtracting close endpoint powers.
    static func powerMean(start: Double, increment: Double, exponent: Double) throws(TerrainLawError) -> Double {
        guard start.isFinite, start >= 0, increment.isFinite, increment > 0,
              exponent.isFinite, exponent >= 1 else { throw .nonFiniteResult }
        let order = try terrainFinite(exponent + 1)
        let mean: Double
        if exponent == 1 {
            mean = try terrainFinite(start + increment / 2)
        } else if start == 0 {
            mean = try terrainFinite(power(increment, exponent) / order)
        } else if increment <= start {
            let ratio = try terrainFinite(increment / start)
            guard ratio > 0 else { throw .nonFiniteResult }
            let logarithm = try terrainFinite(log1p(ratio))
            let numerator = try terrainFinite(expm1(try terrainFinite(order * logarithm)))
            let factor = try terrainFinite(numerator / (order * ratio))
            guard factor > 0 else { throw .nonFiniteResult }
            mean = try terrainFinite(power(start, exponent) * factor)
        } else {
            let endpoint = try terrainFinite(start + increment)
            let ratio = try terrainFinite(start / endpoint)
            let fraction = try terrainFinite((1 - power(ratio, order)) / order)
            mean = try terrainFinite(power(endpoint, exponent) * fraction * (endpoint / increment))
        }
        guard mean > 0 else { throw .nonFiniteResult }
        return mean
    }

    /// Integral mean along the original prescribed sinkage increment, including open gaps.
    static func normalPressureMean(rawStart: Double, increment: Double, peak: Double, plastic: Double,
                                   coefficient: Double, exponent: Double, elastic: Double) throws(TerrainLawError) -> Double {
        guard increment != 0 else { throw .nonFiniteResult }
        if increment < 0 {
            let distance = -increment
            let depth = max(try terrainFinite(rawStart - plastic), 0)
            let active = min(distance, depth)
            if active == 0 { return 0 }
            let mean = try terrainFinite(elastic * (depth - active / 2) * (active / distance))
            guard mean > 0 else { throw .nonFiniteResult }
            return mean
        }
        let gap = min(increment, max(try terrainFinite(plastic - rawStart), 0))
        let remaining = try terrainFinite(increment - gap)
        if remaining == 0 { return 0 }
        let activeStart = max(rawStart, plastic)
        let elasticLength = min(remaining, max(try terrainFinite(peak - activeStart), 0))
        var mean = 0.0
        if elasticLength > 0 {
            let elasticMean = try terrainFinite(elastic * (activeStart - plastic + elasticLength / 2))
            let contribution = try terrainFinite(elasticMean * (elasticLength / increment))
            guard contribution > 0 else { throw .nonFiniteResult }
            mean = contribution
        }
        let envelopeLength = try terrainFinite(remaining - elasticLength)
        if envelopeLength > 0 {
            let envelopeMean = try terrainFinite(coefficient * powerMean(start: max(rawStart, peak),
                increment: envelopeLength, exponent: exponent))
            let contribution = try terrainFinite(envelopeMean * (envelopeLength / increment))
            guard contribution > 0 else { throw .nonFiniteResult }
            mean = try terrainFinite(mean + contribution)
        }
        guard mean > 0 else { throw .nonFiniteResult }
        return mean
    }
    static func mobilization(oldTravel: Double, increment: Double, length: Double,
                             work: inout LoadWork) throws(TerrainLawError) -> Double {
        let oldRatio = try terrainFinite(oldTravel / length)
        let ratio = try terrainFinite(increment / length)
        guard increment == 0 || ratio > 0, oldTravel == 0 || oldRatio > 0 else { throw .nonFiniteResult }
        let initial = try terrainFinite(-expm1(-oldRatio))
        if ratio == 0 { return initial }
        let meanNew: Double
        if ratio > 1 {
            meanNew = try terrainFinite(1 + expm1(-ratio) / ratio)
        } else {
            var sum = 0.0, term = ratio / 2
            guard term > 0 else { throw .nonFiniteResult }
            var converged = false
            for order in 1...32 {
                try terrainLoad { () throws(LoadError) in try work.charge(1) }
                sum = try terrainFinite(sum + term)
                let next = try terrainFinite(-term * ratio / Double(order + 2))
                if abs(next) <= Double.ulpOfOne * abs(sum) {
                    converged = true; break
                }
                term = next
            }
            guard converged else { throw .seriesExhausted }
            meanNew = sum
        }
        let mean = try terrainFinite(initial + (1 - initial) * meanNew)
        guard mean >= 0, mean <= 1 else { throw .physicalAcceptanceFailed }
        return mean
    }
}
