
internal final class HybridBracketEndpoints: Sendable {
    let low: HybridCheckpointOwner
    let high: HybridCheckpointOwner
    init(low: HybridCheckpointOwner, high: HybridCheckpointOwner) { self.low=low; self.high=high }
}
