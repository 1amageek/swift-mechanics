public enum MaterialToothContactEvidence: Sendable {
    case current(ContactCurrentResponse)
    case trial(ContactResponse)
    public var history: ContactHistory {
        switch self { case .current(let value): return value.acceptedHistory; case .trial(let value): return value.trialHistory }
    }
}
