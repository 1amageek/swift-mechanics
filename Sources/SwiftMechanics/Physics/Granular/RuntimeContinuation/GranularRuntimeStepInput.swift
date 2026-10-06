internal final class GranularRuntimeStepInput: Sendable {
    let accepted: GranularRuntimeContinuation
    let random: RuntimeRandomState
    let choice: UInt64
    init(accepted: GranularRuntimeContinuation,random: RuntimeRandomState,choice: UInt64) {
        self.accepted=accepted;self.random=random;self.choice=choice
    }
}
