public struct ScalarLoadResponse: Equatable, Sendable {
    public let conservative: Double
    public let dissipative: Double
    public let active: Double
    public let coordinateDerivative: Double
    public let rateDerivative: Double
    public let potentialEnergy: Double?
    public let dissipatedPower: Double
    public init(conservative: Double, dissipative: Double, active: Double = 0,
                coordinateDerivative: Double, rateDerivative: Double,
                potentialEnergy: Double?, dissipatedPower: Double) throws(LoadError) {
        guard conservative.isFinite, dissipative.isFinite, active.isFinite,
              coordinateDerivative.isFinite, rateDerivative.isFinite, dissipatedPower.isFinite,
              dissipatedPower >= 0 else { throw .invalidInput }
        if let energy = potentialEnergy { guard energy.isFinite else { throw .invalidInput } }
        self.conservative = conservative; self.dissipative = dissipative; self.active = active
        self.coordinateDerivative = coordinateDerivative; self.rateDerivative = rateDerivative
        self.potentialEnergy = potentialEnergy; self.dissipatedPower = dissipatedPower
    }
    public func total() throws(LoadError) -> Double { try loadFinite(conservative + dissipative + active) }
}
