import MechanicsRuntime

internal final class HybridCheckpointOwner: Sendable {
    let checkpoint: RuntimeCheckpoint
    init(_ checkpoint: RuntimeCheckpoint) { self.checkpoint=checkpoint }
}
