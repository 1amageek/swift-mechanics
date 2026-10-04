public struct NativeInlineAsset: Equatable, Sendable {
    public let key:String, format:String
    public let provenance:SourceProvenance
    public let bytes:[UInt8]
    public init(key:String,format:String,provenance:SourceProvenance,bytes:[UInt8]) {
        self.key=key;self.format=format;self.provenance=provenance;self.bytes=bytes
    }
}
