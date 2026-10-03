import MechanicsModel

public struct CollisionSnapshot: Sendable {
    public let proxies: [CollisionProxy]
    public let revision: UInt64

    public init(proxies: [CollisionProxy], revision: UInt64) throws(CollisionError) {
        for i in proxies.indices {
            if let first = proxies.first {
                guard proxies[i].geometry.frameID == first.geometry.frameID,
                      proxies[i].geometry.frameRevision == first.geometry.frameRevision else { throw .frameMismatch }
            }
            for j in 0..<i where proxies[i].geometry.colliderID == proxies[j].geometry.colliderID { throw .invalidIdentity }
        }
        self.proxies = proxies; self.revision = revision
    }

    public func proxy(for id: MechanicsModel.EntityID) throws(CollisionError) -> CollisionProxy {
        for proxy in proxies where proxy.geometry.colliderID == id { return proxy }
        throw .invalidReference
    }
}
