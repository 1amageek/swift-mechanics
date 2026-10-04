public struct CollisionTriggerEvent: Sendable {
    public let pair: CollisionPairIdentity
    public let phase: CollisionTriggerPhase
    public let sampleIndex: UInt64
}
