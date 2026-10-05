/// An infinitesimal-thickness rigid circular disk, with center/axis in its body frame.
public struct RollingWheel: Equatable, Sendable {
    public let body: EntityID
    public let frame: EntityID
    public let center: Vector3
    public let axis: Vector3
    public let radius: Double

    public init(body: EntityID, frame: EntityID, center: Vector3, axis: Vector3,
                radius: Double) throws(RollingError) {
        guard body.kind == .body, frame.kind == .frame, radius.isFinite, radius > 0 else {
            throw .invalidInput
        }
        self.body = body; self.frame = frame; self.center = center; self.radius = radius
        do { self.axis = try axis.normalized() } catch { throw .geometry(error) }
    }
}
