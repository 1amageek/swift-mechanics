public struct InertialRepresentation2D: Equatable, Sendable {
    public let properties: MassProperties2D
    public let provenance: SourceProvenance
    public let quality: InertialQuality

    public init(properties: MassProperties2D, provenance: SourceProvenance, quality: InertialQuality) {
        self.properties = properties
        self.provenance = provenance
        self.quality = quality
    }
}
