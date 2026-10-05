public struct TerrainPatchResponse: Sendable {
    public let step: TerrainContactStep
    public let cells: [TerrainCellResponse]
    public let interfaceWrench: SpatialWrench
    public let terrainWrench: SpatialWrench
    public let meanNormalLoad: Double
    public let interfaceWork: Double
    public let recoverableEnergyChange: Double
    public let compactionLoss: Double
    public let shearLoss: Double
    public let originalEnergyResidual: Double
    public let originalLocalWorldWorkResidual: Double
    public let originalStrengthExcess: Double

    internal init(step: TerrainContactStep, cells: [TerrainCellResponse], interfaceWrench: SpatialWrench,
                  terrainWrench: SpatialWrench, meanNormalLoad: Double, interfaceWork: Double,
                  recoverableEnergyChange: Double, compactionLoss: Double, shearLoss: Double,
                  originalEnergyResidual: Double, originalLocalWorldWorkResidual: Double,
                  originalStrengthExcess: Double) {
        self.step = step; self.cells = cells; self.interfaceWrench = interfaceWrench; self.terrainWrench = terrainWrench
        self.meanNormalLoad = meanNormalLoad; self.interfaceWork = interfaceWork
        self.recoverableEnergyChange = recoverableEnergyChange; self.compactionLoss = compactionLoss
        self.shearLoss = shearLoss; self.originalEnergyResidual = originalEnergyResidual
        self.originalLocalWorldWorkResidual = originalLocalWorldWorkResidual; self.originalStrengthExcess = originalStrengthExcess
    }
}
