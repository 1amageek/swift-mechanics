public struct FieldOutputPolicy: Sendable {
    public let maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumLocations: Int
    public let maximumIdentifierBytes: Int, maximumScalars: Int
    public let minimumCurrentVolume: Double, minimumVolumeRatio: Double
    public let barycentricTolerance: Double, deformationTolerance: Double, strainTolerance: Double
    public let stressTolerance: Double, volumeTolerance: Double, forceTolerance: Double
    public let momentTolerance: Double, powerTolerance: Double, energyTolerance: Double
    public let isCancelled: @Sendable () -> Bool

    public init(maximumNodes: Int, maximumCells: Int, maximumMaterials: Int, maximumLocations: Int,
                maximumIdentifierBytes: Int, maximumScalars: Int, minimumCurrentVolume: Double,
                minimumVolumeRatio: Double, barycentricTolerance: Double, deformationTolerance: Double,
                strainTolerance: Double, stressTolerance: Double, volumeTolerance: Double,
                forceTolerance: Double, momentTolerance: Double, powerTolerance: Double, energyTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(FieldOutputError) {
        guard maximumNodes > 0, maximumCells > 0, maximumMaterials > 0, maximumLocations > 0,
              maximumIdentifierBytes > 0, maximumScalars > 0,
              minimumCurrentVolume.isFinite, minimumCurrentVolume > 0,
              minimumVolumeRatio.isFinite, minimumVolumeRatio > 0,
              barycentricTolerance.isFinite, barycentricTolerance >= 0, barycentricTolerance < 1,
              deformationTolerance.isFinite, deformationTolerance >= 0,
              strainTolerance.isFinite, strainTolerance >= 0, stressTolerance.isFinite, stressTolerance >= 0,
              volumeTolerance.isFinite, volumeTolerance >= 0, forceTolerance.isFinite, forceTolerance >= 0,
              momentTolerance.isFinite, momentTolerance >= 0, powerTolerance.isFinite, powerTolerance >= 0,
              energyTolerance.isFinite, energyTolerance >= 0 else { throw .invalidInput }
        self.maximumNodes = maximumNodes; self.maximumCells = maximumCells; self.maximumMaterials = maximumMaterials
        self.maximumLocations = maximumLocations; self.maximumIdentifierBytes = maximumIdentifierBytes
        self.maximumScalars = maximumScalars; self.minimumCurrentVolume = minimumCurrentVolume
        self.minimumVolumeRatio = minimumVolumeRatio; self.barycentricTolerance = barycentricTolerance
        self.deformationTolerance = deformationTolerance; self.strainTolerance = strainTolerance
        self.stressTolerance = stressTolerance; self.volumeTolerance = volumeTolerance
        self.forceTolerance = forceTolerance; self.momentTolerance = momentTolerance
        self.powerTolerance = powerTolerance; self.energyTolerance = energyTolerance; self.isCancelled = isCancelled
    }
}
