public struct TerrainCellResponse: Sendable {
    public let cellIndex: Int
    public let area: Double
    public let point: Vector3
    public let forceOnInterface: Vector3
    public let meanNormalPressure: Double
    public let endpointNormalPressure: Double
    public let meanShearStress: Double
    public let compactionLoss: Double
    public let shearLoss: Double
    public let recoverableEnergyChange: Double

    internal init(cellIndex: Int, area: Double, point: Vector3, forceOnInterface: Vector3,
                  meanNormalPressure: Double, endpointNormalPressure: Double, meanShearStress: Double,
                  compactionLoss: Double, shearLoss: Double, recoverableEnergyChange: Double) {
        self.cellIndex = cellIndex; self.area = area; self.point = point; self.forceOnInterface = forceOnInterface
        self.meanNormalPressure = meanNormalPressure; self.endpointNormalPressure = endpointNormalPressure
        self.meanShearStress = meanShearStress; self.compactionLoss = compactionLoss
        self.shearLoss = shearLoss; self.recoverableEnergyChange = recoverableEnergyChange
    }
}
