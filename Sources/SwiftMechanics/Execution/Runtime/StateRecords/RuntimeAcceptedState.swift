
public struct RuntimeAcceptedState: Equatable, Sendable {
    public let physical: CompiledKinematicState
    public let checkpoint: RuntimeCheckpoint
    internal init(admission: _RuntimeStateAdmission) { physical = admission.physical; checkpoint = admission.checkpoint }
}
