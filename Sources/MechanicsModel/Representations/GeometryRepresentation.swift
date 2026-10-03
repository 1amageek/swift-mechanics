public struct GeometryRepresentation: Equatable, Sendable {
    public let kind: RepresentationKind
    public let assetKey: String
    public let provenance: SourceProvenance
    public let quality: RepresentationQuality

    public init(kind: RepresentationKind, assetKey: String, provenance: SourceProvenance,
                quality: RepresentationQuality) throws(ModelError) {
        guard !assetKey.isEmpty else { throw .emptyIdentity }
        try quality.validating()
        self.kind = kind
        self.assetKey = assetKey
        self.provenance = provenance
        self.quality = quality
    }
}
