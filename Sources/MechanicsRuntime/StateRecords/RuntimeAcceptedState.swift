import MechanicsCompiler

public struct RuntimeAcceptedState: Equatable, Sendable {
    public let physical: CompiledKinematicState
    public let checkpoint: RuntimeCheckpoint
    internal init(physical: CompiledKinematicState, checkpoint: RuntimeCheckpoint) { self.physical = physical; self.checkpoint = checkpoint }
}
