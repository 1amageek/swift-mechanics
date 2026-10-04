
public struct CompiledKinematicState: Equatable, Sendable {
    public let stamp: ModelStamp
    public let state: KinematicState

    internal init(admission: _CompiledStateAdmission) { stamp = admission.stamp; state = admission.state }
}
