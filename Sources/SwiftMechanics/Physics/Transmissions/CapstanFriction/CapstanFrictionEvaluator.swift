#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A supported scalar math platform is required.")
#endif

public struct CapstanFrictionEvaluator: CapstanFrictionEvaluating {
    public init() {}
    public func sticking(law: CapstanFrictionLaw, upstreamTension: Double, downstreamTension: Double,
                         work: inout ActuationWork) throws(ActuationError) -> CapstanResponse {
        try work.reserve(scalars: 12); try work.charge(16)
        try tension(upstreamTension, law); try tension(downstreamTension, law)
        let high = max(upstreamTension, downstreamTension), low = min(upstreamTension, downstreamTension)
        // Nearby logarithms can round to the same value even for unequal tensions.
        let logRatio = try finite(high / 2 <= low ? log1p((high - low) / low) : log(high) - log(low))
        guard abs(logRatio) <= law.staticCoefficient * law.wrapAngle else { throw .outsideDomain }
        let force = try finite(upstreamTension - downstreamTension)
        try work.charge(0)
        return CapstanResponse(upstreamTension: upstreamTension, downstreamTension: downstreamTension,
                               slipSpeed: 0, cableForce: force, dissipatedPower: 0, sticking: true)
    }
    public func sliding(law: CapstanFrictionLaw, lowTension: Double, slipSpeed: Double,
                        work: inout ActuationWork) throws(ActuationError) -> CapstanResponse {
        try work.reserve(scalars: 12); try work.charge(20)
        try tension(lowTension, law)
        guard slipSpeed.isFinite, slipSpeed != 0 else { throw .invalidInput }
        guard abs(slipSpeed) <= law.maximumSlipSpeed else { throw .outsideDomain }
        let exponent = law.kineticCoefficient * law.wrapAngle
        let difference: Double, high: Double
        if exponent < 0.125 {
            difference = try finite(lowTension * expm1(exponent))
            high = try finite(lowTension + difference)
        } else {
            // Log-domain multiplication supports a finite tension even when exp(exponent) overflows.
            let logHigh = try finite(log(lowTension) + exponent)
            guard logHigh <= log(law.maximumTension) else { throw .outsideDomain }
            high = try finite(exp(logHigh))
            difference = try finite(high - lowTension)
        }
        try tension(high, law)
        // Friction opposes motion: positive travel requires downstream high tension.
        let upstream = slipSpeed > 0 ? lowTension : high
        let downstream = slipSpeed > 0 ? high : lowTension
        let force = slipSpeed > 0 ? -difference : difference
        let heat = try finite(difference * abs(slipSpeed))
        try work.charge(0)
        return CapstanResponse(upstreamTension: upstream, downstreamTension: downstream,
                               slipSpeed: slipSpeed, cableForce: force, dissipatedPower: heat, sticking: false)
    }
    private func tension(_ x: Double, _ law: CapstanFrictionLaw) throws(ActuationError) {
        guard x.isFinite, x > 0 else { throw .invalidInput }
        guard x <= law.maximumTension else { throw .outsideDomain }
    }
    private func finite(_ x: Double) throws(ActuationError) -> Double {
        guard x.isFinite else { throw .nonfiniteResult }; return x
    }
}
