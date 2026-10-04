
public struct CollisionSweep: Sendable {
    public let start: CollisionProxy
    public let end: CollisionProxy

    public init(start: CollisionProxy, end: CollisionProxy) throws(CollisionError) {
        guard start.geometry == end.geometry else { throw .staleGeometry }
        guard start.pose.rotation == end.pose.rotation || start.pose.rotation == end.pose.rotation.negated() else { throw .unsupportedSweep }
        self.start = start; self.end = end
    }

    public func proxy(at fraction: Double) throws(CollisionError) -> CollisionProxy {
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { throw .invalidPolicy }
        if fraction == 0 { return start }
        if fraction == 1 { return end }
        let position = try collisionCore { () throws(CoreError) in
            try start.pose.translation.adding(end.pose.translation.subtracting(start.pose.translation).scaled(by:fraction))
        }
        return start.moved(to:RigidTransform(rotation:start.pose.rotation,translation:position))
    }
}
