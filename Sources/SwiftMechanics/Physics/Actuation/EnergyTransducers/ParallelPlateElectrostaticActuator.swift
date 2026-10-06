public struct ParallelPlateElectrostaticActuator: Equatable, Sendable, EnergyTransducerEvaluating {
    public let permittivity: Double
    public let area: Double
    public let referenceGap: Double
    public let minimumGap: Double
    public let leakageConductance: Double
    private let permittivityArea: Double
    public init(permittivity: Double, area: Double, referenceGap: Double, minimumGap: Double, leakageConductance: Double = 0) throws(ActuationError) {
        guard permittivity.isFinite, area.isFinite, permittivity > 0, area > 0,
              referenceGap.isFinite, minimumGap.isFinite, referenceGap > minimumGap, minimumGap > 0,
              leakageConductance.isFinite, leakageConductance >= 0 else { throw .invalidLaw }
        let product = permittivity * area
        guard product.isFinite, product > 0 else { throw .invalidLaw }
        self.permittivity = permittivity; self.area = area; self.referenceGap = referenceGap
        self.minimumGap = minimumGap; self.leakageConductance = leakageConductance; permittivityArea = product
    }
    public func evaluate(position: Double, electricalState: Double, work: inout ActuationWork) throws(ActuationError) -> ElectromechanicalEnergySample {
        try TransducerArithmetic.preflight(position: position, state: electricalState, work: &work)
        let gap = try TransducerArithmetic.finite(referenceGap - position)
        guard gap >= minimumGap else { throw .outsideDomain }
        let inverse = try TransducerArithmetic.finite(gap / permittivityArea)
        let voltage = try TransducerArithmetic.finite(electricalState * inverse)
        let sample = try ElectromechanicalEnergySample(position: position, state: electricalState, electrical: .charge,
            energy: 0.5 * electricalState * voltage, force: 0.5 * electricalState * (electricalState / permittivityArea), effort: voltage,
            mechanicalTangent: 0, coupling: electricalState / permittivityArea, electricalTangent: inverse,
            lossCoefficient: leakageConductance)
        try work.charge(0); return sample
    }
}
