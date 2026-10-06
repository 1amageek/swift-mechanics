#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct PowerLawDamperEvaluator: PowerLawDamperEvaluating {
    public init() {}
    public func evaluate(law: PowerLawDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.reserve(scalars: 24); try work.charge(48)
        guard rate.isFinite else { throw .invalidInput }
        guard abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let speed = abs(rate)
        let magnitude: Double, slope: Double
        if law.coefficient == 0 { magnitude = 0; slope = 0 }
        else if speed == 0 { magnitude = 0; slope = law.exponent == 1 ? law.coefficient : 0 }
        else {
            magnitude = try finite(law.coefficient * pow(speed, law.exponent))
            slope = try finite(law.coefficient * law.exponent * pow(speed, law.exponent - 1))
        }
        let force = rate < 0 ? magnitude : -magnitude
        let dissipation = try finite(-force * rate)
        try work.charge(0)
        return try ScalarLoadResponse(conservative: 0, dissipative: force, coordinateDerivative: 0,
            rateDerivative: -slope, potentialEnergy: 0, dissipatedPower: dissipation)
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
