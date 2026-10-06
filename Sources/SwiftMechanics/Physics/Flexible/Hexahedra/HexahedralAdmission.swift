public struct HexahedralAdmission: Sendable {
    public let maximumNodes: Int
    public let maximumCells: Int
    public let maximumMaterials: Int
    /// Positive SI m³ determinant bounds on the natural-to-physical mappings.
    public let minimumReferenceDeterminant: Double
    public let minimumCurrentDeterminant: Double
    /// Relative guard subtracted from the Bernstein coefficient lower bound.
    public let certificateRelativeMargin: Double
    public let inverseRelativeTolerance: Double
    public let isCancelled: @Sendable () -> Bool

    public init(maximumNodes: Int, maximumCells: Int, maximumMaterials: Int,
                minimumReferenceDeterminant: Double, minimumCurrentDeterminant: Double,
                certificateRelativeMargin: Double, inverseRelativeTolerance: Double,
                isCancelled: @escaping @Sendable () -> Bool = { false }) throws(HexahedralError) {
        guard maximumNodes > 0, maximumCells > 0, maximumMaterials > 0,
              minimumReferenceDeterminant.isFinite, minimumReferenceDeterminant > 0,
              minimumCurrentDeterminant.isFinite, minimumCurrentDeterminant > 0,
              certificateRelativeMargin.isFinite, certificateRelativeMargin >= 0, certificateRelativeMargin < 1,
              inverseRelativeTolerance.isFinite, inverseRelativeTolerance >= 0 else { throw .invalidParameter }
        self.maximumNodes = maximumNodes
        self.maximumCells = maximumCells
        self.maximumMaterials = maximumMaterials
        self.minimumReferenceDeterminant = minimumReferenceDeterminant
        self.minimumCurrentDeterminant = minimumCurrentDeterminant
        self.certificateRelativeMargin = certificateRelativeMargin
        self.inverseRelativeTolerance = inverseRelativeTolerance
        self.isCancelled = isCancelled
    }
}
