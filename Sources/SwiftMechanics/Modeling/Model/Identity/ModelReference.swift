public struct ModelReference: Equatable, Hashable, Sendable {
    public let id: EntityID
    public let revision: UInt64

    public init(id: EntityID, revision: UInt64) {
        self.id = id
        self.revision = revision
    }

    public func validating(revision current: UInt64) throws(ModelError) {
        guard revision == current else { throw .revisionMismatch }
    }
}
