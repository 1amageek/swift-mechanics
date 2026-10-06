/// Explicit undeformed row-major cell heights; no terrain or empirical defaults.
public struct TerrainGrid: Equatable, Sendable {
    public let source: String
    public let revision: UInt64
    public let terrainBody: ModelReference
    public let material: ModelReference
    public let referenceFrame: ModelReference
    public let terrainToReference: UnitQuaternion
    public let referenceOrigin: Vector3
    public let minimumX: Double
    public let minimumY: Double
    public let cellWidth: Double
    public let cellLength: Double
    public let columns: Int
    public let rows: Int
    public let undeformedHeights: [Double]

    public init(source: String, revision: UInt64, terrainBody: ModelReference, material: ModelReference,
                referenceFrame: ModelReference, terrainToReference: UnitQuaternion, referenceOrigin: Vector3,
                minimumX: Double, minimumY: Double, cellWidth: Double, cellLength: Double,
                columns: Int, rows: Int, undeformedHeights: [Double], maximumCells: Int,
                work: inout LoadWork) throws(TerrainLawError) {
        guard !source.isEmpty, terrainBody.id.kind == .body, material.id.kind == .material,
              referenceFrame.id.kind == .frame, minimumX.isFinite, minimumY.isFinite,
              cellWidth.isFinite, cellWidth > 0, cellLength.isFinite, cellLength > 0,
              columns > 0, rows > 0, maximumCells >= 0 else { throw .invalidGrid }
        let count = try terrainLoad { () throws(LoadError) in try LoadWork.product(columns, rows) }
        guard count <= maximumCells else { throw .cellLimit }
        guard undeformedHeights.count == count else { throw .invalidGrid }
        try terrainReserve(base: 96, perCell: 0, cells: count, work: &work)
        try terrainCharge(source, work: &work); try terrainCharge(terrainBody.id.key, work: &work)
        try terrainCharge(material.id.key, work: &work); try terrainCharge(referenceFrame.id.key, work: &work)
        for index in 0..<count {
            try terrainLoad { () throws(LoadError) in try work.charge(1) }
            let x0 = try terrainFinite(minimumX + Double(index % columns) * cellWidth)
            let x1 = try terrainFinite(minimumX + Double(index % columns + 1) * cellWidth)
            let y0 = try terrainFinite(minimumY + Double(index / columns) * cellLength)
            let y1 = try terrainFinite(minimumY + Double(index / columns + 1) * cellLength)
            guard x1 > x0, y1 > y0, undeformedHeights[index].isFinite else { throw .invalidGrid }
        }
        self.source = source; self.revision = revision; self.terrainBody = terrainBody; self.material = material
        self.referenceFrame = referenceFrame; self.terrainToReference = terrainToReference
        self.referenceOrigin = referenceOrigin; self.minimumX = minimumX; self.minimumY = minimumY
        self.cellWidth = cellWidth; self.cellLength = cellLength; self.columns = columns; self.rows = rows
        self.undeformedHeights = undeformedHeights
        try terrainLoad { () throws(LoadError) in try work.charge(0) }
    }
}
