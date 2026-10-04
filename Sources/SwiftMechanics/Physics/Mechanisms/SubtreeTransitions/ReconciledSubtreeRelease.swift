public final class ReconciledSubtreeRelease: Sendable {
    public let release: SubtreeRelease
    public let physical: KinematicState
    public let system: RigidDynamicsSystem
    public let drive: [Double]
    public let maximumScaledForceResidual: Double
    internal init(admission: _SubtreeAccelerationAdmission) {
        release=admission.release; physical=admission.physical; system=admission.system
        drive=admission.drive; maximumScaledForceResidual=admission.residual
    }
}
