public protocol AssetProviding: Sendable {
    /// One attempt; obey explicit limits, retain original bytes/declarations and record work on success or failure.
    func read(address: AssetAddress, limits: AssetReadLimits, work: inout AssetProviderWork) throws(AssetProviderFailure) -> AssetProviderRecord
}
