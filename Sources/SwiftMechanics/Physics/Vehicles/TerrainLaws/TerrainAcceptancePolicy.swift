public struct TerrainAcceptancePolicy: Equatable, Sendable {
    public let absoluteEnergyTolerance: Double
    public let referenceEnergy: Double
    public let absolutePressureTolerance: Double
    public let referencePressure: Double
    public let absoluteAreaTolerance: Double
    public let relativeTolerance: Double

    public init(absoluteEnergyTolerance: Double, referenceEnergy: Double,
                absolutePressureTolerance: Double, referencePressure: Double,
                absoluteAreaTolerance: Double, relativeTolerance: Double) throws(TerrainLawError) {
        guard absoluteEnergyTolerance.isFinite, absoluteEnergyTolerance >= 0,
              referenceEnergy.isFinite, referenceEnergy > 0,
              absolutePressureTolerance.isFinite, absolutePressureTolerance >= 0,
              referencePressure.isFinite, referencePressure > 0,
              absoluteAreaTolerance.isFinite, absoluteAreaTolerance >= 0,
              relativeTolerance.isFinite, relativeTolerance >= 0, relativeTolerance < 1 else { throw .invalidPolicy }
        self.absoluteEnergyTolerance = absoluteEnergyTolerance; self.referenceEnergy = referenceEnergy
        self.absolutePressureTolerance = absolutePressureTolerance; self.referencePressure = referencePressure
        self.absoluteAreaTolerance = absoluteAreaTolerance; self.relativeTolerance = relativeTolerance
    }
}
