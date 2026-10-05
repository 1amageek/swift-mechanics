/// Sealed accepted state. Only the terrain service can issue or restore this value.
public struct TerrainPatchHistory: Equatable, Sendable {
    public let grid: TerrainGrid
    public let calibration: TerrainSoilCalibration
    public let footprint: TerrainRectangularFootprint
    public let interfaceBody: ModelReference
    public let interfaceHeight: Double
    public let timeSeconds: Double
    public let sequence: UInt64
    public let cells: [TerrainSubareaHistory]

    internal init(grid: TerrainGrid, calibration: TerrainSoilCalibration, footprint: TerrainRectangularFootprint,
                  interfaceBody: ModelReference, interfaceHeight: Double, timeSeconds: Double,
                  sequence: UInt64, cells: [TerrainSubareaHistory]) {
        self.grid = grid; self.calibration = calibration; self.footprint = footprint
        self.interfaceBody = interfaceBody; self.interfaceHeight = interfaceHeight
        self.timeSeconds = timeSeconds; self.sequence = sequence; self.cells = cells
    }
}
