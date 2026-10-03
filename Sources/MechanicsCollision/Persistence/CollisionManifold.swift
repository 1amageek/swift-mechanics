public struct CollisionManifold: Sendable {
    public let pair: CollisionPairIdentity
    public let contacts: [CollisionManifoldContact]
    public let nextContactID: UInt64
}
