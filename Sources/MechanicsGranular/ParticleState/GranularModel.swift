import MechanicsModel
import MechanicsContactLaws
public final class GranularModel: Sendable {
    public let revision: UInt64
    public let frame: ModelReference
    public let particles: [GranularParticle]
    public let boundaries: [GranularBoundary]
    public let bindings: [GranularBinding]
    internal init(revision: UInt64, frame: ModelReference, particles: [GranularParticle], boundaries: [GranularBoundary], bindings: [GranularBinding]) {
        self.revision=revision; self.frame=frame; self.particles=particles; self.boundaries=boundaries; self.bindings=bindings
    }
}
