/// Constant homogeneous interface and terrain velocities; rotational motion is outside this model.
public struct TerrainContactStep: Sendable {
    public let interfaceBody: ModelReference
    public let terrainBody: ModelReference
    public let referenceFrame: ModelReference
    public let gridRevision: UInt64
    public let calibrationRevision: UInt64
    public let footprint: TerrainRectangularFootprint
    public let startTimeSeconds: Double
    public let timeStepSeconds: Double
    public let interfaceVelocity: Vector3
    public let terrainVelocity: Vector3
    public let wrenchReferencePoint: Vector3

    public init(interfaceBody: ModelReference, terrainBody: ModelReference, referenceFrame: ModelReference,
                gridRevision: UInt64, calibrationRevision: UInt64, footprint: TerrainRectangularFootprint,
                startTimeSeconds: Double, timeStepSeconds: Double,
                interfaceVelocity: Vector3, terrainVelocity: Vector3,
                wrenchReferencePoint: Vector3) throws(TerrainLawError) {
        guard interfaceBody.id.kind == .body, terrainBody.id.kind == .body, interfaceBody.id != terrainBody.id,
              referenceFrame.id.kind == .frame, startTimeSeconds.isFinite, startTimeSeconds >= 0,
              timeStepSeconds.isFinite, timeStepSeconds > 0 else { throw .invalidInput }
        self.interfaceBody = interfaceBody; self.terrainBody = terrainBody; self.referenceFrame = referenceFrame
        self.gridRevision = gridRevision; self.calibrationRevision = calibrationRevision; self.footprint = footprint
        self.startTimeSeconds = startTimeSeconds; self.timeStepSeconds = timeStepSeconds
        self.interfaceVelocity = interfaceVelocity; self.terrainVelocity = terrainVelocity
        self.wrenchReferencePoint = wrenchReferencePoint
    }
}
