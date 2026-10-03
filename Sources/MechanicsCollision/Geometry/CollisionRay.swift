import MechanicsCore

public struct CollisionRay: Sendable {
    public let origin: Vector3
    public let direction: Vector3
    public let maximumDistance: Double

    public init(origin: Vector3, direction: Vector3, maximumDistance: Double) throws(CollisionError) {
        guard maximumDistance.isFinite, maximumDistance >= 0 else { throw .invalidRay }
        guard direction != .zero else { throw .invalidRay }
        self.origin = origin
        self.direction = try collisionCore { () throws(CoreError) in try direction.normalized() }
        self.maximumDistance = maximumDistance
    }
}
