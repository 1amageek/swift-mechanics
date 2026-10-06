/// Actual provider-owned source values; the resolver treats construction as untrusted.
public struct AssetProviderRecord: Sendable {
    public let address: AssetAddress
    public let asset: NativeInlineAsset
    public let dependencies: [AssetAddress]
    public init(address: AssetAddress, asset: NativeInlineAsset, dependencies: [AssetAddress]) {
        self.address = address; self.asset = asset; self.dependencies = dependencies
    }
}
