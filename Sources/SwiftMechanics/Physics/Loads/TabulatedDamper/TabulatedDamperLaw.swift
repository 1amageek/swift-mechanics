public struct TabulatedDamperLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let rates: [Double]
    public let restoringEfforts: [Double]
    internal let slopes: [Double]
    public init(coordinateKind: ScalarCoordinateKind, rates: [Double], restoringEfforts: [Double],
                maximumKnots: Int, work: inout LoadWork) throws(LoadError) {
        let count = rates.count
        guard maximumKnots >= 2, count >= 2, count <= maximumKnots,
              count == restoringEfforts.count else { throw .invalidPassiveLaw }
        try work.reserve(scalars: LoadWork.product(count, 3))
        try work.charge(count)
        var zeroIndex: Int? = nil
        for i in 0..<count {
            try work.charge(1)
            guard rates[i].isFinite, restoringEfforts[i].isFinite else { throw .invalidPassiveLaw }
            if rates[i] == 0 {
                guard restoringEfforts[i] == 0 else { throw .invalidPassiveLaw }
                zeroIndex = i
            }
            if i > 0 {
                guard rates[i] > rates[i-1], restoringEfforts[i] >= restoringEfforts[i-1] else { throw .invalidPassiveLaw }
            }
        }
        guard let zero = zeroIndex else { throw .invalidPassiveLaw }
        var slopes = [Double](); slopes.reserveCapacity(count-1)
        for i in 0..<(count-1) {
            try work.charge(1)
            let width = rates[i+1] - rates[i]
            let difference = restoringEfforts[i+1] - restoringEfforts[i]
            let slope = difference / width
            guard width.isFinite, width > 0, difference.isFinite, slope.isFinite, slope >= 0 else { throw .nonFiniteResult }
            slopes.append(slope)
        }
        _ = zero
        try work.charge(0)
        self.coordinateKind = coordinateKind
        self.rates = rates; self.restoringEfforts = restoringEfforts; self.slopes = slopes

    }
}
