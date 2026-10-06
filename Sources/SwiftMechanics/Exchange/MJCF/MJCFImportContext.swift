public struct MJCFImportContext: Sendable {
    public let identity: String
    public let source: SourceProvenance
    public let compilationPolicy: CompilationPolicy
    public let geometry: [MJCFGeometryBinding]
    public let assets: [NativeInlineAsset]
    public let equalityDomain: [MJCFCoordinateDomain]
    public let minimumTime: Double
    public let maximumTime: Double
    public let timeScale: Double
    public let equalityResidualScale: Double
    public let equalityTolerance: NumericalTolerance
    public init(identity: String, source: SourceProvenance, compilationPolicy: CompilationPolicy,
                geometry: [MJCFGeometryBinding] = [], assets: [NativeInlineAsset] = [], equalityDomain: [MJCFCoordinateDomain] = [],
                minimumTime: Double, maximumTime: Double, timeScale: Double,
                equalityResidualScale: Double, equalityTolerance: NumericalTolerance) throws(MJCFError) {
        guard !identity.isEmpty, minimumTime.isFinite, maximumTime.isFinite, minimumTime <= 0, maximumTime >= 0,
              minimumTime <= maximumTime, timeScale.isFinite, timeScale > 0,
              equalityResidualScale.isFinite, equalityResidualScale > 0 else { throw .invalidInput(node: -1, field: "context") }
        self.identity = identity; self.source = source; self.compilationPolicy = compilationPolicy
        self.geometry = geometry; self.assets = assets; self.equalityDomain = equalityDomain
        self.minimumTime = minimumTime; self.maximumTime = maximumTime; self.timeScale = timeScale
        self.equalityResidualScale = equalityResidualScale; self.equalityTolerance = equalityTolerance
    }
}
