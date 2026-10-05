/// Point and positive normal are expressed in the named plane frame.
public enum RollingPlaneBinding: Sendable {
    case body(body: EntityID, frame: EntityID, point: Vector3, normal: Vector3)
    case prescribed(frame: EntityID, sourceID: String, sourceRevision: UInt64, point: Vector3, normal: Vector3)
}
