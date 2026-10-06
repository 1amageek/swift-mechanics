public struct SDFScene: Sendable {
    public let source: SourceProvenance
    public let worldFrame: EntityID
    public let worldName: String?
    public let assemblies: [SDFAssembly]
    public let frames: [SDFResolvedFrame]
    public let assets: [SDFAssetReference]
    public let losses: [SDFLoss]
    public let originalDocument: XMLDocument
    internal init(source: SourceProvenance, worldFrame: EntityID, worldName: String?,
                  assemblies: [SDFAssembly], frames: [SDFResolvedFrame], assets: [SDFAssetReference],
                  losses: [SDFLoss], originalDocument: XMLDocument) {
        self.source = source; self.worldFrame = worldFrame; self.worldName = worldName
        self.assemblies = assemblies; self.frames = frames; self.assets = assets; self.losses = losses
        self.originalDocument = originalDocument
    }
}
