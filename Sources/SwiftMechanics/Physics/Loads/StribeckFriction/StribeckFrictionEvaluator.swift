#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct StribeckFrictionEvaluator: StribeckFrictionEvaluating {
    public init() {}
    public func evaluate(law: StribeckFrictionLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.reserve(scalars: 24); try work.charge(48)
        guard rate.isFinite else { throw .invalidInput }
        guard abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let s = try finite(rate / law.stribeckRate), r = try finite(rate / law.regularizationRate)
        let square = try finite(s * s), decay = exp(-square), smoothSign = tanh(r)
        let tail = try finite((law.lowSpeedEffort - law.coulombEffort) * decay)
        let amplitude = try finite(law.coulombEffort + tail)
        let amplitudeDerivative = try finite(-2 * (tail * s) / law.stribeckRate)
        let force = try finite(-amplitude * smoothSign - law.viscousCoefficient * rate)
        let tangent = try finite(-amplitudeDerivative * smoothSign
            - amplitude * (1 - smoothSign * smoothSign) / law.regularizationRate - law.viscousCoefficient)
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
