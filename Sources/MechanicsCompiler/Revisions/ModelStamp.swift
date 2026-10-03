public struct ModelStamp: Equatable, Hashable, Sendable {
    public let identity: String
    public let revision: UInt64

    public init(identity: String, revision: UInt64) { self.identity = identity; self.revision = revision }
}
