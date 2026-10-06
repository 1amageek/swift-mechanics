public struct ReluctanceSolenoid: Equatable, Sendable, EnergyTransducerEvaluating {
    public let inductanceLengthProduct: Double
    public let referenceGap: Double
    public let minimumGap: Double
    public let resistance: Double
    public init(inductanceLengthProduct: Double, referenceGap: Double, minimumGap: Double, resistance: Double = 0) throws(ActuationError) {
        guard inductanceLengthProduct.isFinite, inductanceLengthProduct > 0,
              referenceGap.isFinite, minimumGap.isFinite, referenceGap > minimumGap, minimumGap > 0,
              resistance.isFinite, resistance >= 0 else { throw .invalidLaw }
        self.inductanceLengthProduct = inductanceLengthProduct; self.referenceGap = referenceGap
        self.minimumGap = minimumGap; self.resistance = resistance
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        let gap = try TransducerArithmetic.finite(referenceGap - position)
        guard gap >= minimumGap else { throw .outsideDomain }
        let inverse = try TransducerArithmetic.finite(gap / inductanceLengthProduct)
        let current = try TransducerArithmetic.finite(electricalState * inverse)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, electrical: .fluxLinkage,
            energy: 0.5 * electricalState * current, force: 0.5 * electricalState * (electricalState / inductanceLengthProduct), effort: current,
            mechanicalTangent: 0, coupling: electricalState / inductanceLengthProduct,
            electricalTangent: inverse, lossCoefficient: resistance)
        try work.charge(0); return sample
    }
}
