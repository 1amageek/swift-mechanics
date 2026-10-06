public struct TabulatedDamperEvaluator: TabulatedDamperEvaluating {
    public init() {}
    public func evaluate(law: TabulatedDamperLaw, rate: Double, work: inout LoadWork) throws(LoadError) -> TabulatedDamperResponse {
        try work.reserve(scalars: 16); try work.charge(1)
        guard rate.isFinite else { throw .invalidInput }
        let sample = rate
        let count = law.rates.count
        guard sample >= law.rates[0], sample <= law.rates[count-1] else { throw .outsideDomain }
        var lower = 0, upper = count - 1
        while lower < upper {
            try work.charge(1)
            let middle = lower + (upper - lower) / 2
            if law.rates[middle] < sample { lower = middle + 1 } else { upper = middle }
        }
        let index = lower, exact = law.rates[index] == sample
        let slope = law.slopes[exact ? min(index, count - 2) : index - 1]
        // The endpoint nearest zero preserves tiny signed effort without subtractive cancellation.
        let origin = exact ? index : (sample < 0 ? index : index - 1)
        let value = exact ? law.restoringEfforts[index] :
            law.restoringEfforts[origin] + slope * (sample - law.rates[origin])
        guard value.isFinite else { throw .nonFiniteResult }
        let left: Double? = exact ? (index > 0 ? -law.slopes[index-1] : nil) : -slope
        let right: Double? = exact ? (index < count - 1 ? -law.slopes[index] : nil) : -slope
        let dissipation = value * rate
        guard dissipation.isFinite, dissipation >= 0 else { throw .nonFiniteResult }
        try work.charge(0)
        return TabulatedDamperResponse(effort: -value, dissipatedPower: dissipation, leftRateDerivative: left, rightRateDerivative: right)
    }
}
