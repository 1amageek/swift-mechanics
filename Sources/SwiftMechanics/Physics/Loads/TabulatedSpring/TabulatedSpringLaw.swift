public struct TabulatedSpringLaw: Equatable, Sendable {
    public let coordinateKind: ScalarCoordinateKind
    public let restCoordinate: Double
    public let maximumRate: Double
    public let displacements: [Double]
    public let restoringEfforts: [Double]
    internal let slopes: [Double]
    internal let energies: [Double]
    public init(coordinateKind: ScalarCoordinateKind, restCoordinate: Double, maximumRate: Double, displacements: [Double], restoringEfforts: [Double],
                maximumKnots: Int, work: inout LoadWork) throws(LoadError) {
        let count = displacements.count
        guard restCoordinate.isFinite, maximumRate.isFinite, maximumRate >= 0, maximumKnots >= 2, count >= 2, count <= maximumKnots,
              count == restoringEfforts.count else { throw .invalidPassiveLaw }
        try work.reserve(scalars: LoadWork.product(count, 4))
        try work.charge(count)
        var zeroIndex: Int? = nil
        for i in 0..<count {
            try work.charge(1)
            guard displacements[i].isFinite, restoringEfforts[i].isFinite else { throw .invalidPassiveLaw }
            if displacements[i] == 0 {
                guard restoringEfforts[i] == 0 else { throw .invalidPassiveLaw }
                zeroIndex = i
            }
            if i > 0 {
                guard displacements[i] > displacements[i-1], restoringEfforts[i] >= restoringEfforts[i-1] else { throw .invalidPassiveLaw }
            }
        }
        guard let zero = zeroIndex else { throw .invalidPassiveLaw }
        var slopes = [Double](); slopes.reserveCapacity(count-1)
        for i in 0..<(count-1) {
            try work.charge(1)
            let width = displacements[i+1] - displacements[i]
            let difference = restoringEfforts[i+1] - restoringEfforts[i]
            let slope = difference / width
            guard width.isFinite, width > 0, difference.isFinite, slope.isFinite, slope >= 0 else { throw .nonFiniteResult }
            slopes.append(slope)
        }
        var energies = [Double](repeating: 0, count: count)
        if zero > 0 {
            for i in stride(from: zero - 1, through: 0, by: -1) {
                try work.charge(1)
                let increment = -(restoringEfforts[i] / 2 + restoringEfforts[i+1] / 2) * (displacements[i+1] - displacements[i])
                let energy = energies[i+1] + increment
                guard energy.isFinite, energy >= 0 else { throw .nonFiniteResult }
                energies[i] = energy
            }
        }
        if zero + 1 < count {
            for i in (zero + 1)..<count {
                try work.charge(1)
                let increment = (restoringEfforts[i-1] / 2 + restoringEfforts[i] / 2) * (displacements[i] - displacements[i-1])
                let energy = energies[i-1] + increment
                guard energy.isFinite, energy >= 0 else { throw .nonFiniteResult }
                energies[i] = energy
            }
        }
        try work.charge(0)
        self.coordinateKind = coordinateKind
        self.restCoordinate = restCoordinate; self.maximumRate = maximumRate
        self.displacements = displacements; self.restoringEfforts = restoringEfforts; self.slopes = slopes
        self.energies = energies
    }
}
