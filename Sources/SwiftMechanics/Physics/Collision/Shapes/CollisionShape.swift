
public enum CollisionShape: Equatable, Sendable {
    case sphere(radius: Double)
    case box(halfExtents: Vector3)
    /// Solid local half-space z <= 0.
    case halfSpace

    public func validate() throws(CollisionError) {
        switch self {
        case .sphere(let radius):
            guard radius.isFinite, radius > 0 else { throw .invalidShape }
        case .box(let h):
            guard h.x > 0, h.y > 0, h.z > 0 else { throw .invalidShape }
        case .halfSpace: break
        }
    }
}
