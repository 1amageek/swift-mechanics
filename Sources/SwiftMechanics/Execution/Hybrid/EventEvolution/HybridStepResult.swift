
internal final class HybridStepResult: Sendable {
    let accepted: RuntimeAcceptedState
    let impulse: NormalImpulseResult?
    init(accepted: RuntimeAcceptedState, impulse: NormalImpulseResult?) { self.accepted=accepted; self.impulse=impulse }
}
