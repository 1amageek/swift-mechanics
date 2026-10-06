public struct CableEvolutionEvidence: Sendable {
    public let duration: Double
    public let acceptedSubsteps: Int
    public let attempts: Int
    public let initialMechanicalEnergy: Double
    public let finalMechanicalEnergy: Double
    public let externalWork: Double
    public let dampingWorkLoss: Double
    public let originalEnergyResidual: Double
    public let maximumSubstepEnergyResidual: Double
    public let maximumMomentumResidual: Double
    public let maximumAngularMomentumResidual: Double
    public let accumulatedSupportImpulse: [Vector3]
    public let numericalWork: NumericalWork
}
