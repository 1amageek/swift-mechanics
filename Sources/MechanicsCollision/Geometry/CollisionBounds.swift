import MechanicsCore

public enum CollisionBounds: Sendable {
    case finite(minimum: Vector3, maximum: Vector3)
    case unbounded

    public func overlaps(_ other: CollisionBounds) -> Bool {
        switch (self, other) {
        case (.unbounded, _), (_, .unbounded): true
        case (.finite(let amin, let amax), .finite(let bmin, let bmax)):
            amin.x <= bmax.x && bmin.x <= amax.x &&
            amin.y <= bmax.y && bmin.y <= amax.y &&
            amin.z <= bmax.z && bmin.z <= amax.z
        }
    }

    public func union(_ other: CollisionBounds) throws(CollisionError) -> CollisionBounds {
        switch (self, other) {
        case (.unbounded, _), (_, .unbounded): return .unbounded
        case (.finite(let a, let b), .finite(let c, let d)):
            let lower = try collisionCore { () throws(CoreError) in try Vector3(min(a.x,c.x),min(a.y,c.y),min(a.z,c.z)) }
            let upper = try collisionCore { () throws(CoreError) in try Vector3(max(b.x,d.x),max(b.y,d.y),max(b.z,d.z)) }
            return .finite(minimum: lower, maximum: upper)
        }
    }
}
