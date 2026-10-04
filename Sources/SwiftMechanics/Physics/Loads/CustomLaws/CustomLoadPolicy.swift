public struct CustomLoadPolicy: Equatable, Sendable {
    public let minimumCoordinate: Double
    public let maximumCoordinate: Double
    public let maximumAbsoluteRate: Double
    public let coordinateProbe: Double
    public let rateProbe: Double
    public let absoluteTolerance: Double
    public let relativeTolerance: Double
    public let requireConservativeEnergy: Bool
    public init(minimumCoordinate: Double, maximumCoordinate: Double, maximumAbsoluteRate: Double,
                coordinateProbe: Double, rateProbe: Double, absoluteTolerance: Double,
                relativeTolerance: Double, requireConservativeEnergy: Bool) throws(LoadError) {
        guard minimumCoordinate.isFinite, maximumCoordinate.isFinite, maximumAbsoluteRate.isFinite,
              coordinateProbe.isFinite, rateProbe.isFinite, absoluteTolerance.isFinite, relativeTolerance.isFinite,
              minimumCoordinate < maximumCoordinate, maximumAbsoluteRate > 0, coordinateProbe > 0, rateProbe > 0,
              absoluteTolerance >= 0, relativeTolerance >= 0 else { throw .invalidInput }
        self.minimumCoordinate = minimumCoordinate; self.maximumCoordinate = maximumCoordinate
        self.maximumAbsoluteRate = maximumAbsoluteRate; self.coordinateProbe = coordinateProbe; self.rateProbe = rateProbe
        self.absoluteTolerance = absoluteTolerance; self.relativeTolerance = relativeTolerance
        self.requireConservativeEnergy = requireConservativeEnergy
    }
    internal func admits(coordinate: Double, rate: Double) -> Bool {
        coordinate.isFinite && rate.isFinite && coordinate >= minimumCoordinate && coordinate <= maximumCoordinate && abs(rate) <= maximumAbsoluteRate
    }
    internal func agrees(_ a: Double, _ b: Double) throws(LoadError) -> Bool {
        let bound = try loadFinite(absoluteTolerance + relativeTolerance * max(abs(a), abs(b)))
        return try abs(loadFinite(a - b)) <= bound
    }
}
