/// Original retained-row acceleration evidence; distinct from free forward-acceleration evidence.
@available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
public final class NonlinearReconciledSubtreeRelease: Sendable {
    public let release:SubtreeRelease
    public let physical:KinematicState
    public let descriptor:ODEDescriptor
    public let motion:ConstrainedMotion
    internal init(admission:_NonlinearSubtreeAccelerationAdmission) {
        release=admission.release;physical=admission.physical;descriptor=admission.descriptor;motion=admission.motion
    }
}
