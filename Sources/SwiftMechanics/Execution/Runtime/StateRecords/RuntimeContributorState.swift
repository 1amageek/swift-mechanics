public struct RuntimeContributorState: Equatable, Sendable {
    public let id: String
    public let category: RuntimeContributorCategory
    public let version: UInt64
    public let bytes: [UInt8]
    public init(id: String, category: RuntimeContributorCategory, version: UInt64, bytes: [UInt8]) throws(RuntimeFailure) {
        guard !id.isEmpty, version > 0 else { throw RuntimeFailure(.invalidInput, contributor: id, message: "Contributor payload requires identity and positive version.") }
        self.id = id; self.category = category; self.version = version; self.bytes = bytes
    }
}
