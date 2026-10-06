/// Caller-owned opaque namespace admission; this is not a filesystem handle or download grant.
public struct SDFAssetRoot: Sendable {
    public let key: String
    public let allowedSchemes: [String]
    public let allowedPathPrefixes: [String]
    public init(key: String, allowedSchemes: [String], allowedPathPrefixes: [String]) throws(SDFError) {
        guard !key.isEmpty, !allowedPathPrefixes.isEmpty,
              allowedSchemes.allSatisfy({ !$0.isEmpty }), allowedPathPrefixes.allSatisfy({ !$0.isEmpty && $0.hasSuffix("/") }) else { throw .invalidInput(node: 0) }
        self.key = key; self.allowedSchemes = allowedSchemes; self.allowedPathPrefixes = allowedPathPrefixes
    }
}
