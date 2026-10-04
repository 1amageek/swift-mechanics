
internal final class HybridSegment: Sendable {
    let checkpoint: RuntimeCheckpoint
    let impulse: NormalImpulseResult?
    init(checkpoint: RuntimeCheckpoint, impulse: NormalImpulseResult?) { self.checkpoint=checkpoint; self.impulse=impulse }
}
