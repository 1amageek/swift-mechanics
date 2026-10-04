public struct StructuralPolicy: Sendable {
    public let maximumCoordinates: Int
    public let maximumMetadataBytes: Int
    public let energyScale: Double
    public let timeScale: Double
    public let spectralTolerance: Double
    public let positiveMassThreshold: Double
    public let originalResidualTolerance: Double
    public let zeroEigenvalueThreshold: Double
    public let isCancelled: @Sendable () -> Bool
    public init(maximumCoordinates: Int, maximumMetadataBytes: Int, energyScale: Double, timeScale: Double,
                spectralTolerance: Double, positiveMassThreshold: Double, originalResidualTolerance: Double,
                zeroEigenvalueThreshold: Double, isCancelled: @escaping @Sendable () -> Bool) throws(StructuralError) {
        guard maximumCoordinates > 0, maximumMetadataBytes >= 0, energyScale.isFinite, energyScale > 0,
              timeScale.isFinite, timeScale > 0, spectralTolerance.isFinite, spectralTolerance > 0,
              positiveMassThreshold.isFinite, positiveMassThreshold > 0, originalResidualTolerance.isFinite,
              originalResidualTolerance > 0, zeroEigenvalueThreshold.isFinite, zeroEigenvalueThreshold >= 0 else { throw .invalidInput }
        self.maximumCoordinates=maximumCoordinates;self.maximumMetadataBytes=maximumMetadataBytes;self.energyScale=energyScale;self.timeScale=timeScale
        self.spectralTolerance=spectralTolerance;self.positiveMassThreshold=positiveMassThreshold
        self.originalResidualTolerance=originalResidualTolerance;self.zeroEigenvalueThreshold=zeroEigenvalueThreshold;self.isCancelled=isCancelled
    }
}
