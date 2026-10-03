public struct RuntimeContributorSchema: Equatable, Sendable {
    public let id: String
    public let category: RuntimeContributorCategory
    public let version: UInt64
    public let maximumBytes: Int
    public init(id: String, category: RuntimeContributorCategory, version: UInt64, maximumBytes: Int) throws(RuntimeFailure) {
        guard !id.isEmpty, version > 0, maximumBytes >= 0 else { throw RuntimeFailure(.invalidInput, contributor: id, message: "Contributor schema requires identity, positive version and nonnegative byte bound.") }
        self.id = id; self.category = category; self.version = version; self.maximumBytes = maximumBytes
    }
}
