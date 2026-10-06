#if canImport(Darwin)
import Darwin
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(Glibc)
import Glibc
#else
#error("A scalar math platform is required.")
#endif

public struct SalientPoleReluctanceMotor: Equatable, Sendable, EnergyTransducerEvaluating {
    public let meanInductance: Double
    public let harmonicInductance: Double
    public let harmonicOrder: Int
    public let resistance: Double
    public init(meanInductance: Double, harmonicInductance: Double, harmonicOrder: Int, resistance: Double = 0) throws(ActuationError) {
        guard meanInductance.isFinite, harmonicInductance.isFinite, meanInductance > abs(harmonicInductance),
              harmonicOrder > 0, Double(exactly: harmonicOrder) != nil,
              resistance.isFinite, resistance >= 0 else { throw .invalidLaw }
        self.meanInductance = meanInductance; self.harmonicInductance = harmonicInductance
        self.harmonicOrder = harmonicOrder; self.resistance = resistance
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        let order = Double(harmonicOrder), angle = try TransducerArithmetic.finite(order * position)
        let cosine = cos(angle), inductance = try TransducerArithmetic.finite(meanInductance + harmonicInductance * cosine)
        guard inductance > 0 else { throw .outsideDomain }
        let first = try TransducerArithmetic.finite(-harmonicInductance * order * sin(angle))
        let second = try TransducerArithmetic.finite(-harmonicInductance * order * order * cosine)
        let current = try TransducerArithmetic.finite(electricalState / inductance)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, mechanical: .rotation, electrical: .fluxLinkage,
            energy: 0.5 * electricalState * current, force: 0.5 * current * current * first, effort: current,
            mechanicalTangent: 0.5 * current * current * (second - 2 * first * (first / inductance)),
            coupling: current * (first / inductance), electricalTangent: 1 / inductance, lossCoefficient: resistance)
        try work.charge(0); return sample
    }
}
