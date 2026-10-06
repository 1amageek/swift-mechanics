public protocol ParticleFlowOperating: Sendable {
    func prepare(model: ParticleFlowModel, particles: [FlowParticle], time: Double,
                 policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowState
    func evaluate(_ state: ParticleFlowState, expected: ParticleFlowIdentity, timeStep: Double?,
                  policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowDiagnostics
    func trial(_ state: ParticleFlowState, expected: ParticleFlowIdentity, timeStep: Double,
               policy: ParticleFlowPolicy, work: inout NumericalWork) throws(ParticleFlowError) -> ParticleFlowTrial
}
