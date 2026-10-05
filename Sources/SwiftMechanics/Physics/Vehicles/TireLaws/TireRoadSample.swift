/// Instantaneous wheel motion and translating, nonrotating planar road contact data.
public struct TireRoadSample: Sendable {
    public let tire: ModelReference
    public let roadSurface: ModelReference
    public let referenceFrame: ModelReference
    public let calibrationRevision: UInt64
    public let timeSeconds: Double
    public let centerPosition: Vector3
    public let centerVelocity: Vector3
    public let roadContactVelocity: Vector3
    public let spin: Double
    public let radius: Double
    public let normalLoad: Double

    public init(tire: ModelReference, roadSurface: ModelReference, referenceFrame: ModelReference,
                calibrationRevision: UInt64, timeSeconds: Double, centerPosition: Vector3,
                centerVelocity: Vector3, roadContactVelocity: Vector3, spin: Double,
                radius: Double, normalLoad: Double) throws(TireLawError) {
        guard tire.id.kind == .body, roadSurface.id.kind == .material, referenceFrame.id.kind == .frame,
              timeSeconds.isFinite, timeSeconds >= 0, spin.isFinite,
              radius.isFinite, radius > 0, normalLoad.isFinite, normalLoad > 0 else { throw .invalidInput }
        self.tire = tire; self.roadSurface = roadSurface; self.referenceFrame = referenceFrame
        self.calibrationRevision = calibrationRevision; self.timeSeconds = timeSeconds
        self.centerPosition = centerPosition; self.centerVelocity = centerVelocity
        self.roadContactVelocity = roadContactVelocity; self.spin = spin
        self.radius = radius; self.normalLoad = normalLoad
    }
}
