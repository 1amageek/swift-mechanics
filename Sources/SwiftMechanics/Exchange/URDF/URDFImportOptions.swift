public struct URDFImportOptions: Sendable {
    public enum Units: Sendable { case metresKilogramsSecondsRadians }
    public enum LossMode: Sendable { case prohibit, preserveUnservedRepresentations }
    public enum RootPlacement: Sendable { case fixed(RigidTransform), spatialFloating(RigidTransform) }

    public let identity: String
    public let provenance: SourceProvenance
    public let worldFrame: EntityID
    public let rootName: String
    public let rootPlacement: RootPlacement
    public let units: Units
    public let lossMode: LossMode
    /// An opaque caller-owned asset namespace. This service never opens it.
    public let assetBase: String?
    public init(identity: String, provenance: SourceProvenance, worldFrame: EntityID, rootName: String,
                rootPlacement: RootPlacement, units: Units, lossMode: LossMode, assetBase: String?) {
        self.identity = identity; self.provenance = provenance; self.worldFrame = worldFrame
        self.rootName = rootName; self.rootPlacement = rootPlacement; self.units = units
        self.lossMode = lossMode; self.assetBase = assetBase
    }
}
