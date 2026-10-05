public struct ParticleFlowTrial: Sendable {
    public let originalRevision: UInt64
    public let candidate: ParticleFlowState
    public let initialDiagnostics: ParticleFlowDiagnostics
    public let midpointDiagnostics: ParticleFlowDiagnostics
    public let endpointDiagnostics: ParticleFlowDiagnostics
    public let momentumResidual: Double
    public let energyResidual: Double
    public let prescribedMechanicalWork: Double
    public let pressureReservoirWork: Double
    public let boundaryImpulse: Vector3
    public let work: NumericalWork
}
