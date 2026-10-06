public struct TabulatedSpringEvaluator: TabulatedSpringEvaluating {
    public init() {}
    public func evaluate(law: TabulatedSpringLaw, coordinate: Double, rate: Double, work: inout LoadWork) throws(LoadError) -> TabulatedSpringResponse {
        try work.reserve(scalars: 16); try work.charge(1)
        guard coordinate.isFinite, rate.isFinite else { throw .invalidInput }
        let sample = coordinate - law.restCoordinate
        guard sample.isFinite else { throw .nonFiniteResult }
        guard abs(rate) <= law.maximumRate else { throw .outsideDomain }
        let count = law.displacements.count
        guard sample >= law.displacements[0], sample <= law.displacements[count-1] else { throw .outsideDomain }
        var lower = 0, upper = count - 1
        while lower < upper {
            try work.charge(1)
            let middle = lower + (upper - lower) / 2
            if law.displacements[middle] < sample { lower = middle + 1 } else { upper = middle }
        }
        let index = lower, exact = law.displacements[index] == sample
        let slope = law.slopes[exact ? min(index, count - 2) : index - 1]
        // The endpoint nearest zero preserves tiny signed effort without subtractive cancellation.
        let origin = exact ? index : (sample < 0 ? index : index - 1)
        let value = exact ? law.restoringEfforts[index] :
            law.restoringEfforts[origin] + slope * (sample - law.displacements[origin])
        guard value.isFinite else { throw .nonFiniteResult }
        let left: Double? = exact ? (index > 0 ? -law.slopes[index-1] : nil) : -slope
        let right: Double? = exact ? (index < count - 1 ? -law.slopes[index] : nil) : -slope
        let energy: Double
        if exact { energy = law.energies[index] }
        else {
            // Integrate outward from the endpoint nearest zero; each term is nonnegative.
            let delta = sample - law.displacements[origin]
            energy = law.energies[origin] + law.restoringEfforts[origin] * delta + 0.5 * slope * delta * delta
        }
        guard energy.isFinite, energy >= 0 else { throw .nonFiniteResult }
        try work.charge(0)
        return TabulatedSpringResponse(effort: -value, potentialEnergy: energy, leftCoordinateDerivative: left, rightCoordinateDerivative: right)
    }
}
