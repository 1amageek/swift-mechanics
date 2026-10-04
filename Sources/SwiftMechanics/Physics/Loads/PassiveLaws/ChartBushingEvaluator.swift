public struct ChartBushingEvaluator: ChartBushingEvaluating {
    public init() {}
    public func evaluate(_ bushing: PassiveChartBushing, strain: [Double], rate: [Double], work: inout LoadWork) throws(LoadError) -> ChartBushingResponse {
        guard strain.count == 6, rate.count == 6 else { throw .invalidShape }
        for i in 0..<6 {
            guard strain[i].isFinite, rate[i].isFinite else { throw .invalidInput }
            guard abs(strain[i]) <= bushing.maximumAbsoluteStrain[i], abs(rate[i]) <= bushing.maximumAbsoluteRate[i] else { throw .outsideDomain }
        }
        try work.reserve(scalars: 12)
        var elastic = [Double](repeating: 0, count: 6), damping = [Double](repeating: 0, count: 6)
        let energy = try apply(bushing.stiffnessFactor, to: strain, into: &elastic, work: &work) / 2
        let dissipation = try apply(bushing.dampingFactor, to: rate, into: &damping, work: &work)
        return ChartBushingResponse(frame: bushing.frame, conservative: elastic, dissipative: damping, potentialEnergy: energy, dissipatedPower: dissipation)
    }
    private func apply(_ factor: [Double], to vector: [Double], into result: inout [Double], work: inout LoadWork) throws(LoadError) -> Double {
        var normSquared = 0.0
        for row in 0..<(factor.count / 6) {
            try work.charge(1)
            var image = 0.0
            for i in 0..<6 { image = try loadFinite(image + factor[row * 6 + i] * vector[i]) }
            normSquared = try loadFinite(normSquared + image * image)
            for i in 0..<6 { result[i] = try loadFinite(result[i] - factor[row * 6 + i] * image) }
        }
        return normSquared
    }
    /// Row-major derivative of conjugate load with respect to strain or rate.
    public func tangent(_ bushing: PassiveChartBushing, damping: Bool, work: inout LoadWork) throws(LoadError) -> [Double] {
        try work.reserve(scalars: 36)
        let factor = damping ? bushing.dampingFactor : bushing.stiffnessFactor
        var result = [Double](repeating: 0, count: 36)
        for row in 0..<(factor.count / 6) {
            try work.charge(1)
            for i in 0..<6 { for j in 0..<6 { result[i * 6 + j] = try loadFinite(result[i * 6 + j] - factor[row * 6 + i] * factor[row * 6 + j]) } }
        }
        return result
    }
}
