/// Only an admitted original evaluation constructs a state. Candidate publication is caller-owned.
public struct ParticleFlowState: Equatable, Sendable {
    public let model: ParticleFlowModel
    public let revision: UInt64
    public let time: Double
    public let particles: [FlowParticle]
    public let densities: [Double]
    public let pressures: [Double]
    public let barotropicEnergies: [Double]
    internal init(model: ParticleFlowModel, revision: UInt64, time: Double, particles: [FlowParticle],
                  densities: [Double], pressures: [Double], barotropicEnergies: [Double]) {
        self.model = model; self.revision = revision; self.time = time; self.particles = particles
        self.densities = densities; self.pressures = pressures; self.barotropicEnergies = barotropicEnergies
    }
}
