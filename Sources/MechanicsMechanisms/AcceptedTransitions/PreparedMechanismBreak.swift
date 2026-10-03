import MechanicsRuntime

public final class PreparedMechanismBreak: Sendable {
    public let source:RuntimeAcceptedState
    public let transition:DetachedLeafTransition
    public let contributor:MechanismBreakContributor
    internal init(source:RuntimeAcceptedState,transition:DetachedLeafTransition,contributor:MechanismBreakContributor) {
        self.source=source;self.transition=transition;self.contributor=contributor
    }
}
