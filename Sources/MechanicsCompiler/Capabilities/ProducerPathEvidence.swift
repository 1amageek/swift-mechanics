public struct ProducerPathEvidence: Equatable, Sendable {
    public let owner: String
    public let revision: String
    public let scope: String

    public init(owner: String, revision: String, scope: String) {
        self.owner = owner; self.revision = revision; self.scope = scope
    }
}
