/// Complete original physical source plus the shared accepted motion evidence.
public final class PhysicalConstrainedMotion: Sendable {
    public let system: PhysicalRigidDynamicsSystem
    public let motion: ConstrainedMotion
    internal init(system: PhysicalRigidDynamicsSystem, motion: ConstrainedMotion) {
        self.system = system; self.motion = motion
    }
}
