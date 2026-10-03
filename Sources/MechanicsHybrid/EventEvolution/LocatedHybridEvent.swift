import MechanicsRuntime

internal final class LocatedHybridEvent: Sendable {
    let eventID: UInt64
    let checkpoint: RuntimeCheckpoint
    let bracketLower: Double
    let bracketUpper: Double
    init(eventID: UInt64, checkpoint: RuntimeCheckpoint, bracketLower: Double, bracketUpper: Double) { self.eventID=eventID; self.checkpoint=checkpoint; self.bracketLower=bracketLower; self.bracketUpper=bracketUpper }
}
