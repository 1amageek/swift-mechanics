public struct RefinementPolicy: Sendable {
    public let maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumEdges: Int, maximumFaces: Int
    public let maximumIdentifierBytes: Int, maximumScalars: Int
    public let conformityTolerance: Double, barycentricTolerance: Double, volumeTolerance: Double, areaTolerance: Double
    public let minimumCurrentVolume: Double, forceTolerance: Double, momentTolerance: Double, powerTolerance: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumEdges: Int, maximumFaces: Int,
                maximumIdentifierBytes: Int, maximumScalars: Int, conformityTolerance: Double,
                barycentricTolerance: Double, volumeTolerance: Double, areaTolerance: Double, minimumCurrentVolume: Double,
                forceTolerance: Double, momentTolerance: Double, powerTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(RefinementError) {
        guard maximumNodes > 0, maximumCells > 0, maximumMaterials > 0, maximumEdges > 0, maximumFaces > 0,
              maximumIdentifierBytes > 0, maximumScalars > 0,
              conformityTolerance.isFinite, conformityTolerance >= 0,
              barycentricTolerance.isFinite, barycentricTolerance >= 0, barycentricTolerance < 1,
              volumeTolerance.isFinite, volumeTolerance >= 0, areaTolerance.isFinite, areaTolerance >= 0,
              minimumCurrentVolume.isFinite, minimumCurrentVolume > 0,
              forceTolerance.isFinite, forceTolerance >= 0, momentTolerance.isFinite, momentTolerance >= 0,
              powerTolerance.isFinite, powerTolerance >= 0 else { throw .invalidInput }
        self.maximumNodes = maximumNodes; self.maximumCells = maximumCells; self.maximumEdges = maximumEdges
        self.maximumMaterials = maximumMaterials
        self.maximumFaces = maximumFaces; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.maximumScalars = maximumScalars; self.conformityTolerance = conformityTolerance
        self.barycentricTolerance = barycentricTolerance; self.volumeTolerance = volumeTolerance
        self.areaTolerance = areaTolerance
        self.minimumCurrentVolume = minimumCurrentVolume; self.forceTolerance = forceTolerance
        self.momentTolerance = momentTolerance; self.powerTolerance = powerTolerance; self.isCancelled = isCancelled
    }
}
