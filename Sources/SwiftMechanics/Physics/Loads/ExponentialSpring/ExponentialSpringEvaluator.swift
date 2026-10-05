#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct ExponentialSpringEvaluator: ExponentialSpringEvaluating {
    public init() {}
    public func evaluate(law: ExponentialSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        try work.reserve(scalars: 24); try work.charge(48)
        guard coordinate.isFinite, rate.isFinite else { throw .invalidInput }
        let x = try finite(coordinate - law.restCoordinate)
        guard abs(x) <= law.maximumDisplacement, abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let y = try finite(x / law.lengthScale)
        let elastic = try finite(-law.stiffness * law.lengthScale * sinh(y))
        let halfStretch = try finite(law.lengthScale * sinh(y / 2))
        let energy = try finite(2 * law.stiffness * halfStretch * halfStretch)
        let tangent = try finite(-law.stiffness * cosh(y))
        try work.charge(0)
        return try ScalarLoadResponse(conservative: elastic, dissipative: 0, coordinateDerivative: tangent,
            rateDerivative: 0, potentialEnergy: energy, dissipatedPower: 0)
    }
    private func finite(_ value: Double) throws(LoadError) -> Double {
        guard value.isFinite else { throw .nonFiniteResult }
        return value
    }
}
