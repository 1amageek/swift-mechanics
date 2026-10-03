/// A material feature identity scoped to its physical body's reference.
public struct ContactMaterialSite: Equatable, Sendable {
    public let key: String
    public let revision: UInt64

    public init(key: String, revision: UInt64) throws(ContactLawError) {
        guard !key.isEmpty else { throw .invalidIdentity }
        self.key = key
        self.revision = revision
    }
}
