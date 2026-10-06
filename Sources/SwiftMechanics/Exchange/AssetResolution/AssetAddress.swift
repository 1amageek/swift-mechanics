/// Untrusted address input. Resolution validates the explicit base and safe relative path against caller limits.
public struct AssetAddress: Sendable {
    public let base: String
    public let relativePath: String
    public init(base: String, relativePath: String) { self.base = base; self.relativePath = relativePath }
}
