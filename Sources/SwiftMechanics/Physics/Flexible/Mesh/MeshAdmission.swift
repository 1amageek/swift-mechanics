public struct MeshAdmission: Sendable {
    public let maximumNodes: Int
    public let maximumCells: Int
    public let maximumMaterials: Int
    public let minimumReferenceVolume: Double
    public let inverseRelativeTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, minimumReferenceVolume: Double, inverseRelativeTolerance: Double, isCancelled: @escaping @Sendable () -> Bool = { false }) throws(FlexibleError) {
        guard maximumNodes > 0, maximumCells > 0, maximumMaterials > 0, minimumReferenceVolume.isFinite, minimumReferenceVolume > 0,
              inverseRelativeTolerance.isFinite, inverseRelativeTolerance >= 0 else { throw .invalidParameter }
        self.maximumNodes = maximumNodes; self.maximumCells = maximumCells; self.maximumMaterials = maximumMaterials
        self.minimumReferenceVolume = minimumReferenceVolume; self.inverseRelativeTolerance = inverseRelativeTolerance; self.isCancelled = isCancelled
    }
}
