public struct CADGearBindingPolicy: Sendable {
    public let lengthTolerance: Double
    public let directionTolerance: Double
    public let moduleTolerance: Double
    public let pressureRatioTolerance: Double
    public let maximumModelRecords: Int
    public let maximumMetadataBytes: Int
    public init(lengthTolerance: Double, directionTolerance: Double, moduleTolerance: Double,
                pressureRatioTolerance: Double, maximumModelRecords: Int,
                maximumMetadataBytes: Int) throws(CADGearBindingError) {
        guard lengthTolerance.isFinite, lengthTolerance >= 0,
              directionTolerance.isFinite, directionTolerance >= 0, directionTolerance < 1,
              moduleTolerance.isFinite, moduleTolerance >= 0,
              pressureRatioTolerance.isFinite, pressureRatioTolerance >= 0,
              maximumModelRecords >= 0, maximumMetadataBytes >= 0 else { throw .invalidInput }
        self.lengthTolerance = lengthTolerance; self.directionTolerance = directionTolerance
        self.moduleTolerance = moduleTolerance; self.pressureRatioTolerance = pressureRatioTolerance
        self.maximumModelRecords = maximumModelRecords; self.maximumMetadataBytes = maximumMetadataBytes
    }
}
