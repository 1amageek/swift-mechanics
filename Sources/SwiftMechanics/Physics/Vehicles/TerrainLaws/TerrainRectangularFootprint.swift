public struct TerrainRectangularFootprint: Equatable, Sendable {
    public let minimumX: Double
    public let maximumX: Double
    public let minimumY: Double
    public let maximumY: Double
    public let width: Double
    public let area: Double

    public init(minimumX: Double, maximumX: Double, minimumY: Double, maximumY: Double) throws(TerrainLawError) {
        guard minimumX.isFinite, maximumX.isFinite, minimumY.isFinite, maximumY.isFinite,
              maximumX > minimumX, maximumY > minimumY else { throw .invalidInput }
        let dx = try terrainFinite(maximumX - minimumX), dy = try terrainFinite(maximumY - minimumY)
        let area = try terrainFinite(dx * dy)
        guard area > 0 else { throw .invalidInput }
        self.minimumX = minimumX; self.maximumX = maximumX; self.minimumY = minimumY; self.maximumY = maximumY
        self.width = min(dx, dy); self.area = area
    }
}
