public struct EntityID: Equatable, Hashable, Sendable {
    public let kind: EntityKind
    public let key: String

    public init(kind: EntityKind, key: String) throws(ModelError) {
        guard !key.isEmpty else { throw .emptyIdentity }
        self.kind = kind
        self.key = key
    }
}
