#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct RegularizedYieldDamperEvaluator: RegularizedYieldDamperEvaluating {
    public init() {}
    public func evaluate(law: RegularizedYieldDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.reserve(scalars: 24); try work.charge(48)
        guard rate.isFinite else { throw .invalidInput }
        guard abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let ratio = try finite(abs(rate) / law.regularizationRate)
        let yieldMagnitude = try finite(law.yieldEffort * -expm1(-ratio))
        let yieldForce = rate < 0 ? yieldMagnitude : -yieldMagnitude
        let force = try finite(yieldForce - law.viscousCoefficient * rate)
        let tangent = try finite(-law.yieldEffort / law.regularizationRate * exp(-ratio) - law.viscousCoefficient)
        let dissipation = try finite(-force * rate)
        try work.charge(0)
        return try ScalarLoadResponse(conservative: 0, dissipative: force, coordinateDerivative: 0,
            rateDerivative: tangent, potentialEnergy: 0, dissipatedPower: dissipation)
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
