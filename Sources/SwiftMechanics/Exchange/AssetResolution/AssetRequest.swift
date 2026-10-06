/// Caller authority for original bytes and the complete ordered declared dependency inventory.
public struct AssetRequest: Sendable {
    public let address: AssetAddress
    public let original: NativeInlineAsset
    public let dependencies: [AssetAddress]
    public init(address: AssetAddress, original: NativeInlineAsset, dependencies: [AssetAddress]) {
        self.address = address; self.original = original; self.dependencies = dependencies
    }
}
