public struct PiezoelectricTransducer: Equatable, Sendable, EnergyTransducerEvaluating {
    public let capacitance: Double
    public let chargeDisplacementCoefficient: Double
    public let stiffness: Double
    public let leakageConductance: Double
    public init(capacitance: Double, chargeDisplacementCoefficient: Double, stiffness: Double, leakageConductance: Double = 0) throws(ActuationError) {
        guard capacitance.isFinite, capacitance > 0, chargeDisplacementCoefficient.isFinite, chargeDisplacementCoefficient != 0,
              stiffness.isFinite, stiffness > 0, leakageConductance.isFinite, leakageConductance >= 0 else { throw .invalidLaw }
        self.capacitance = capacitance; self.chargeDisplacementCoefficient = chargeDisplacementCoefficient
        self.stiffness = stiffness; self.leakageConductance = leakageConductance
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        let charge = try TransducerArithmetic.finite(electricalState - chargeDisplacementCoefficient * position)
        let voltage = try TransducerArithmetic.finite(charge / capacitance)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, electrical: .charge,
            energy: 0.5 * charge * voltage + 0.5 * stiffness * position * position,
            force: chargeDisplacementCoefficient * voltage - stiffness * position, effort: voltage,
            mechanicalTangent: -chargeDisplacementCoefficient * (chargeDisplacementCoefficient / capacitance) - stiffness,
            coupling: chargeDisplacementCoefficient / capacitance, electricalTangent: 1 / capacitance,
            lossCoefficient: leakageConductance)
        try work.charge(0); return sample
    }
}
