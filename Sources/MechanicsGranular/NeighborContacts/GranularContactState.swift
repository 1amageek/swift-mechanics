import MechanicsContactLaws
public struct GranularContactState: Sendable {
    public let history: ContactHistory
    public let basis: ContactBasis?
    internal init(history: ContactHistory, basis: ContactBasis?) { self.history=history; self.basis=basis }
}
