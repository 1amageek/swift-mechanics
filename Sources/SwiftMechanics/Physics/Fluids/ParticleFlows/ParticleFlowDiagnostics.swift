public struct ParticleFlowDiagnostics: Equatable, Sendable {
    public let totalFiniteMass: Double
    public let momentum: Vector3
    public let totalEnergy: Double
    public let pressureInternalPower: Double
    public let viscousLoss: Double
    public let viscousHeatPower: Double
    public let boundaryReactions: [ParticleFlowBoundaryReaction]
    public let originalMomentumRateResidual: Double
    public let originalEnergyRateResidual: Double
    /// Maximum original per-particle equation residual divided by its caller SI characteristic scale.
    public let maximumEquationResidual: Double
    public let pairCandidates: Int
    public let activePairs: Int
    public let maximumMach: Double
    /// Nil means no time step was requested; the ratio then carries no stability admission.
    public let evaluatedTimeStep: Double?
    public let maximumTimeStepRatio: Double
}
