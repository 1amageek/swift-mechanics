public struct ElectrostaticCombDrive: Equatable, Sendable, EnergyTransducerEvaluating {
    public let referenceCapacitance: Double
    public let capacitanceGradient: Double
    public let minimumPosition: Double
    public let maximumPosition: Double
    public let leakageConductance: Double
    public init(referenceCapacitance: Double, capacitanceGradient: Double, minimumPosition: Double, maximumPosition: Double,
                leakageConductance: Double = 0) throws(ActuationError) {
        guard referenceCapacitance.isFinite, referenceCapacitance > 0, capacitanceGradient.isFinite, capacitanceGradient != 0,
              minimumPosition.isFinite, maximumPosition.isFinite, minimumPosition < maximumPosition,
              leakageConductance.isFinite, leakageConductance >= 0 else { throw .invalidLaw }
        let low = referenceCapacitance + capacitanceGradient * minimumPosition
        let high = referenceCapacitance + capacitanceGradient * maximumPosition
        guard low.isFinite, high.isFinite, low > 0, high > 0 else { throw .invalidLaw }
        self.referenceCapacitance = referenceCapacitance; self.capacitanceGradient = capacitanceGradient
        self.minimumPosition = minimumPosition; self.maximumPosition = maximumPosition; self.leakageConductance = leakageConductance
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        guard position >= minimumPosition, position <= maximumPosition else { throw .outsideDomain }
        let capacitance = try TransducerArithmetic.finite(referenceCapacitance + capacitanceGradient * position)
        guard capacitance > 0 else { throw .outsideDomain }
        let voltage = try TransducerArithmetic.finite(electricalState / capacitance)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, electrical: .charge,
            energy: 0.5 * electricalState * voltage, force: 0.5 * voltage * voltage * capacitanceGradient, effort: voltage,
            mechanicalTangent: -voltage * voltage * capacitanceGradient * (capacitanceGradient / capacitance),
            coupling: voltage * (capacitanceGradient / capacitance), electricalTangent: 1 / capacitance,
            lossCoefficient: leakageConductance)
        try work.charge(0); return sample
    }
}
