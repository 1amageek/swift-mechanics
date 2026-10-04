
public struct MechanismEngagement: Sendable {
    public let accepted:RuntimeAcceptedState
    public let impulse:ConstrainedMotion
    internal init(accepted:RuntimeAcceptedState,impulse:ConstrainedMotion) { self.accepted=accepted;self.impulse=impulse }
}
