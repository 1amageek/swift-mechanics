public struct SourceProvenance: Equatable, Hashable, Sendable {
    public let source: String
    public let revision: UInt64

    public init(source: String, revision: UInt64) throws(ModelError) {
        guard !source.isEmpty else { throw .emptyIdentity }
        self.source = source
        self.revision = revision
    }
}
