import MechanicsModel

public struct CollisionPairKey: Equatable, Sendable {
    public let first: EntityID
    public let second: EntityID

    public init(_ a: EntityID, _ b: EntityID) throws(CollisionError) {
        guard a.kind == .collider, b.kind == .collider, a != b else { throw .invalidIdentity }
        if a.key < b.key { first = a; second = b } else { first = b; second = a }
    }

    public func precedes(_ other: CollisionPairKey) -> Bool {
        first.key == other.first.key ? second.key < other.second.key : first.key < other.first.key
    }
}
