#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct FiniteExtensionSpringEvaluator: FiniteExtensionSpringEvaluating {
    public init() {}
    public func evaluate(law: FiniteExtensionSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.reserve(scalars: 24); try work.charge(48)
        guard coordinate.isFinite, rate.isFinite else { throw .invalidInput }
        let x = try finite(coordinate - law.restCoordinate)
        guard abs(x) <= law.maximumDisplacement, abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let y = try finite(x / law.limitingExtension), y2 = y * y
        let denominator = 1 - y2
        guard denominator > 0 else { throw .outsideDomain }
        let elastic = try finite(-law.stiffness * x / denominator)
        let energyFactor = y2 == 0 ? 1 : -log1p(-y2) / y2
        let energy = try finite(0.5 * law.stiffness * x * x * energyFactor)
        let tangent = try finite(-law.stiffness * (1 + y2) / denominator / denominator)
        try work.charge(0)
        return try ScalarLoadResponse(conservative: elastic, dissipative: 0, coordinateDerivative: tangent,
            rateDerivative: 0, potentialEnergy: energy, dissipatedPower: 0)
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
