public struct CollisionTriggerState: Sendable {
    public let intersections: [CollisionPairIdentity]
    public let sampleIndex: UInt64
}
