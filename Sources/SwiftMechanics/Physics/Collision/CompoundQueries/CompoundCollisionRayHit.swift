/// Original child hit; overlapping children can expose boundaries internal to their union.
public struct CompoundCollisionRayHit: Sendable {
    public let assembly: CompoundCollisionIdentity
    public let localChild: CollisionProxy
    public let hit: CollisionRayHit
    public var approximationError: Double { hit.geometry.approximationError }

    internal init(placement: CompoundCollisionPlacement, localChild: CollisionProxy, hit: CollisionRayHit) {
        assembly = placement.compound.identity; self.localChild = localChild; self.hit = hit
    }
}
