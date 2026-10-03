public struct ScalarLoadEvaluator: ScalarLoadEvaluating {
    public init() {}
    public func evaluate(_ law: PolynomialSpringDamper, coordinate: Double, rate: Double,
                         work: inout LoadWork) throws(LoadError) -> ScalarLoadResponse {
        guard coordinate.isFinite, rate.isFinite else { throw .invalidInput }
        let x = coordinate - law.restCoordinate
        guard x.isFinite, abs(x) <= law.maximumDisplacement, abs(rate) <= law.maximumRate else { throw .outsideDomain }
        try work.charge(1)
        let x2 = x * x, v2 = rate * rate
        let elastic = try loadFinite(-(law.quadraticStiffness * x + law.quarticStiffness * x2 * x))
        let damping = try loadFinite(-(law.linearDamping * rate + law.cubicDamping * v2 * rate))
        return try ScalarLoadResponse(conservative: elastic, dissipative: damping,
            coordinateDerivative: loadFinite(-law.quadraticStiffness - 3 * law.quarticStiffness * x2),
            rateDerivative: loadFinite(-law.linearDamping - 3 * law.cubicDamping * v2),
            potentialEnergy: loadFinite(law.quadraticStiffness * x2 / 2 + law.quarticStiffness * x2 * x2 / 4),
            dissipatedPower: loadFinite(-damping * rate))
    }
}
