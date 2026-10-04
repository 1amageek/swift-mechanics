
internal final class SelectedHybridEvents: Sendable {
    let checkpoint: RuntimeCheckpoint
    let eventIDs: [UInt64]
    init(checkpoint: RuntimeCheckpoint, eventIDs: [UInt64]) { self.checkpoint=checkpoint; self.eventIDs=eventIDs }
}
