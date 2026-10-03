public struct InertialRepresentation3D: Equatable, Sendable {
    public let properties: MassProperties3D
    public let provenance: SourceProvenance
    public let quality: InertialQuality

    public init(properties: MassProperties3D, provenance: SourceProvenance, quality: InertialQuality) {
        self.properties = properties
        self.provenance = provenance
        self.quality = quality
    }
}
