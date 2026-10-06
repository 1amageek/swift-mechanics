public struct SDFImportOptions: Sendable {
    public enum Units: Equatable, Sendable { case metresKilogramsSecondsRadians }
    public enum InitialState: Equatable, Sendable { case restAtReferenceConfiguration }
    public enum UnservedRecords: Equatable, Sendable { case prohibit, preserveOriginalWithExplicitLosses }
    public let identity: String
    public let source: SourceProvenance
    public let worldFrame: EntityID
    public let units: Units
    public let initialState: InitialState
    public let time: Double
    public let standaloneGravity: Vector3
    public let inertiaQuality: InertialQuality
    public let unservedRecords: UnservedRecords
    public let assetRoot: SDFAssetRoot?
    public init(identity: String, source: SourceProvenance, worldFrame: EntityID, units: Units,
                initialState: InitialState, time: Double, standaloneGravity: Vector3,
                inertiaQuality: InertialQuality, unservedRecords: UnservedRecords,
                assetRoot: SDFAssetRoot?) throws(SDFError) {
        guard !identity.isEmpty, worldFrame.kind == .frame, time.isFinite else { throw .invalidInput(node: 0) }
        self.identity = identity; self.source = source; self.worldFrame = worldFrame; self.units = units
        self.initialState = initialState; self.time = time; self.standaloneGravity = standaloneGravity
        self.inertiaQuality = inertiaQuality; self.unservedRecords = unservedRecords; self.assetRoot = assetRoot
    }
}
