public struct ElectromechanicalEnergySample: Equatable, Sendable {
    public let position: Double
    public let electricalState: Double
    public let mechanicalCoordinate: ScalarCoordinateKind
    public let electricalCoordinate: ElectricalCoordinateKind
    public let storedEnergy: Double
    public let mechanicalEffort: Double
    public let electricalEffort: Double
    public let mechanicalTangent: Double
    public let coupling: Double
    public let electricalTangent: Double
    public let lossCoefficient: Double

    internal init(position: Double, state: Double, mechanical: ScalarCoordinateKind = .translation,
                  electrical: ElectricalCoordinateKind, energy: Double, force: Double, effort: Double,
                  mechanicalTangent: Double, coupling: Double, electricalTangent: Double,
                  lossCoefficient: Double) throws(ActuationError) {
        guard position.isFinite, state.isFinite, energy.isFinite, energy >= 0,
              force.isFinite, effort.isFinite, mechanicalTangent.isFinite, coupling.isFinite,
              electricalTangent.isFinite, electricalTangent > 0,
              lossCoefficient.isFinite, lossCoefficient >= 0 else { throw .nonfiniteResult }
        self.position = position; electricalState = state; mechanicalCoordinate = mechanical
        electricalCoordinate = electrical; storedEnergy = energy; mechanicalEffort = force
        electricalEffort = effort; self.mechanicalTangent = mechanicalTangent; self.coupling = coupling
        self.electricalTangent = electricalTangent; self.lossCoefficient = lossCoefficient
    }

    public func power(mechanicalRate: Double, electricalRate: Double, work: inout ActuationWork)
        throws(ActuationError) -> ElectromechanicalPower {
        try work.reserve(scalars: 16); try work.charge(32)
        guard mechanicalRate.isFinite, electricalRate.isFinite else { throw .invalidInput }
        let drive = try TransducerArithmetic.finite(electricalRate + lossCoefficient * electricalEffort)
        let source = try TransducerArithmetic.finite(electricalEffort * drive)
        let field = try TransducerArithmetic.finite(electricalEffort * electricalRate)
        let mechanical = try TransducerArithmetic.finite(mechanicalEffort * mechanicalRate)
        let storage = try TransducerArithmetic.finite(-mechanicalEffort * mechanicalRate + electricalEffort * electricalRate)
        let loss = try TransducerArithmetic.finite(lossCoefficient * electricalEffort * electricalEffort)
        let residual = try TransducerArithmetic.finite(source - mechanical - storage - loss)
        try work.charge(0)
        return ElectromechanicalPower(driveEffort: drive, sourcePower: source, fieldPower: field,
            mechanicalPower: mechanical, storagePower: storage, physicalLoss: loss, balanceResidual: residual)
    }
}
