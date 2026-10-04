public struct FluidChannel: Equatable, Sendable {
    public let id: String
    public let revision: UInt64
    public let model: ModelStamp
    public let frame: EntityID
    public let source: SourceProvenance
    public let boundaryLaw: String
    public let boundaryRevision: UInt64
    public let height: Double
    public let wallArea: Double
    public let density: Double
    public let viscosity: Double
    public let accelerationX: Double
    public let accelerationY: Double
    public let cells: Int
    public let limits: FluidLimits
    public var spacing: Double { height/Double(cells) }
    public var cellMass: Double { density*wallArea*spacing }
    public var conductance: Double { viscosity*wallArea/spacing }
    public init(id: String, revision: UInt64, model: ModelStamp, frame: EntityID, source: SourceProvenance,
                boundaryLaw: String, boundaryRevision: UInt64, height: Double, wallArea: Double,
                density: Double, viscosity: Double, accelerationX: Double, accelerationY: Double,
                cells: Int, limits: FluidLimits) throws(FluidError) {
        guard cells > 0, cells < Int.max, cells <= limits.maximumCells else { throw .capacity }
        var remaining=limits.maximumMetadataBytes
        for text in [id,model.identity,frame.key,source.source,boundaryLaw] {
            guard !text.isEmpty else { throw .invalidInput }
            for _ in text.utf8 { guard remaining > 0 else { throw .capacity }; remaining -= 1 }
        }
        guard frame.kind == .frame, height.isFinite, height > 0, wallArea.isFinite, wallArea > 0,
              density.isFinite, density > 0, viscosity.isFinite, viscosity > 0,
              accelerationX.isFinite, accelerationY.isFinite else { throw .invalidInput }
        self.id=id; self.revision=revision; self.model=model; self.frame=frame; self.source=source
        self.boundaryLaw=boundaryLaw; self.boundaryRevision=boundaryRevision; self.height=height
        self.wallArea=wallArea; self.density=density; self.viscosity=viscosity
        self.accelerationX=accelerationX; self.accelerationY=accelerationY; self.cells=cells; self.limits=limits
        guard spacing.isFinite, spacing > 0, cellMass.isFinite, cellMass > 0,
              conductance.isFinite, conductance > 0 else { throw .nonfinite }
    }
}
