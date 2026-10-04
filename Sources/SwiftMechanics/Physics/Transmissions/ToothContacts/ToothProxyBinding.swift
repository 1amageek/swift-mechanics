public struct ToothProxyBinding: Equatable, Sendable {
    public let toothID: UInt64
    public let proxy: CollisionProxy
    public let colliderToBody: RigidTransform
    public init(toothID: UInt64, proxy: CollisionProxy, colliderToBody: RigidTransform) {
        self.toothID=toothID; self.proxy=proxy; self.colliderToBody=colliderToBody
    }
}
