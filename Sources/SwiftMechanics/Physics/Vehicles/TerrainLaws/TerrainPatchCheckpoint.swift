/// Immutable in-memory checkpoint; serialization is a separate responsibility.
public struct TerrainPatchCheckpoint: Sendable {
    public static let formatRevision: UInt64 = 1
    public let timeSeconds: Double
    public let sequence: UInt64
    internal let accepted: TerrainPatchHistory

    internal init(accepted: TerrainPatchHistory) {
        self.accepted = accepted; self.timeSeconds = accepted.timeSeconds; self.sequence = accepted.sequence
    }
}
