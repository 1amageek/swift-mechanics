/// Soil state belongs to the fixed clipped subarea, not the entire grid cell.
public struct TerrainSubareaHistory: Equatable, Sendable {
    public let cellIndex: Int
    public let area: Double
    public let centroidX: Double
    public let centroidY: Double
    public let currentSinkage: Double
    public let peakSinkage: Double
    public let irreversibleSinkage: Double
    public let shearTravel: Double
    public let recoverableEnergy: Double
    public let cumulativeCompactionLoss: Double
    public let cumulativeShearLoss: Double

    internal init(cellIndex: Int, area: Double, centroidX: Double, centroidY: Double,
                  currentSinkage: Double, peakSinkage: Double, irreversibleSinkage: Double,
                  shearTravel: Double, recoverableEnergy: Double,
                  cumulativeCompactionLoss: Double, cumulativeShearLoss: Double) {
        self.cellIndex = cellIndex; self.area = area; self.centroidX = centroidX; self.centroidY = centroidY
        self.currentSinkage = currentSinkage; self.peakSinkage = peakSinkage
        self.irreversibleSinkage = irreversibleSinkage; self.shearTravel = shearTravel
        self.recoverableEnergy = recoverableEnergy; self.cumulativeCompactionLoss = cumulativeCompactionLoss
        self.cumulativeShearLoss = cumulativeShearLoss
    }
}
