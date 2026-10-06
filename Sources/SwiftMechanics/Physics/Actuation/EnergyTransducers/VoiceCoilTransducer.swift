public struct VoiceCoilTransducer: Equatable, Sendable, EnergyTransducerEvaluating {
    public let inductance: Double
    public let forceConstant: Double
    public let resistance: Double
    public init(inductance: Double, forceConstant: Double, resistance: Double = 0) throws(ActuationError) {
        guard inductance.isFinite, inductance > 0, forceConstant.isFinite, forceConstant != 0,
              resistance.isFinite, resistance >= 0 else { throw .invalidLaw }
        self.inductance = inductance; self.forceConstant = forceConstant; self.resistance = resistance
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        let flux = try TransducerArithmetic.finite(electricalState - forceConstant * position)
        let current = try TransducerArithmetic.finite(flux / inductance)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, electrical: .fluxLinkage,
            energy: 0.5 * flux * current, force: forceConstant * current, effort: current,
            mechanicalTangent: -forceConstant * (forceConstant / inductance), coupling: forceConstant / inductance,
            electricalTangent: 1 / inductance, lossCoefficient: resistance)
        try work.charge(0); return sample
    }
}
