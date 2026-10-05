public struct URDFAssetReference: Equatable, Sendable {
    public let base: String
    public let relativePath: String
    public let location: XMLLocation
    /// Producer-admitted but unresolved. No file existence or content claim is made.
    internal init(base: String, relativePath: String, location: XMLLocation) {
        self.base = base; self.relativePath = relativePath; self.location = location
    }
}
