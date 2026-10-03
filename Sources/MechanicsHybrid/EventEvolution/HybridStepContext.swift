import MechanicsRuntime

internal final class HybridStepContext: Sendable {
    let source: RuntimeCheckpoint
    let history: HybridHistory
    init(source: RuntimeCheckpoint, history: HybridHistory) { self.source=source; self.history=history }
}
