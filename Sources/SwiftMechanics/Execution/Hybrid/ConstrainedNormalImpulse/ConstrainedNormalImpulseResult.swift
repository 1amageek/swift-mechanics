public final class ConstrainedNormalImpulseResult: Sendable {
    public let source: PreparedConstrainedImpact
    public var time: Double { source.source.physical.state.time }
    public var eventID: UInt64 { source.impact.contacts[0].eventID }
    public let contactImpulse: Double
    /// Energy-times-time multipliers in the original retained normalized row order.
    public let retainedImpulses: [Double]
    public let retainedGeneralizedImpulse: [Double]
    public let velocity: [Double]
    public let normalSpeedBefore: Double
    public let normalSpeedAfter: Double
    public let effectiveInverseMass: Double
    public let kineticEnergyBefore: Double
    public let kineticEnergyAfter: Double
    public let predictedLostEnergy: Double
    public let normalizedMomentumResidual: Double
    public let normalizedConstraintResidual: Double
    public let lawResidual: Double
    public let energyResidual: Double
    internal init(source: PreparedConstrainedImpact, candidate: ConstrainedImpactCandidate,
                  energyBefore: Double, energyAfter: Double, momentum: Double, constraint: Double,
                  law: Double, energy: Double) {
        self.source = source; contactImpulse = candidate.impulses[source.retainedRowIDs.count]
        retainedImpulses = Array(candidate.impulses.dropLast()); retainedGeneralizedImpulse = candidate.reaction
        velocity = candidate.velocity; normalSpeedBefore = candidate.mode.before; normalSpeedAfter = candidate.after
        effectiveInverseMass = candidate.mode.inverseMass; kineticEnergyBefore = energyBefore; kineticEnergyAfter = energyAfter
        predictedLostEnergy = candidate.prediction.lostNormalEnergy; normalizedMomentumResidual = momentum
        normalizedConstraintResidual = constraint; lawResidual = law; energyResidual = energy
    }
}
