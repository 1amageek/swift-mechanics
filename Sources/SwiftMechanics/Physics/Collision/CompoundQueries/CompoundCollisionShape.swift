/// Immutable rigid child inventory. Child poses map into the identified assembly-local frame.
public struct CompoundCollisionShape: Sendable {
    public let identity: CompoundCollisionIdentity
    public let lengthUnit: UnitDefinition
    public let children: [CollisionProxy]
    public let metadataBytes: Int

    public init(identity: CompoundCollisionIdentity, lengthUnit: UnitDefinition, children: [CollisionProxy],
                policy: CompoundCollisionPolicy, work: inout CollisionWork) throws(CompoundCollisionError) {
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        guard !children.isEmpty, children.count <= policy.maximumChildren else { throw .invalidChildren }
        guard lengthUnit.dimension == .length, lengthUnit.scale == 1, lengthUnit.offset == 0 else { throw .invalidUnit }
        try CompoundCollisionAccounting.storage(children: children.count, outputs: 0, work: &work)
        var metadata = 0
        for value in [identity.colliderID.key, identity.bodyID.key, identity.localFrameID.key,
                      identity.provenance.source, lengthUnit.symbol] {
            try CompoundCollisionAccounting.text(value, bytes: &metadata, policy: policy, work: &work)
        }
        var ordered = [CollisionProxy]()
        ordered.reserveCapacity(children.count)
        for child in children {
            let g = child.geometry
            guard g.colliderID != identity.colliderID, g.bodyID == identity.bodyID,
                  g.frameID == identity.localFrameID, g.frameRevision == identity.localFrameRevision else { throw .invalidIdentity }
            for value in [g.colliderID.key, g.bodyID.key, g.frameID.key, g.representation.assetKey, g.representation.provenance.source] {
                try CompoundCollisionAccounting.text(value, bytes: &metadata, policy: policy, work: &work)
            }
            try CompoundCollisionAccounting.run { () throws(CollisionError) in
                try work.charge(CollisionWork.sum(32, CollisionWork.product(8, ordered.count)))
            }
            for previous in ordered where previous.geometry.colliderID == g.colliderID { throw .invalidIdentity }
            var index = ordered.count
            while index > 0 && g.colliderID.key < ordered[index - 1].geometry.colliderID.key { index -= 1 }
            ordered.insert(child, at: index)
        }
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        self.identity = identity; self.lengthUnit = lengthUnit; self.children = ordered
        metadataBytes = metadata
    }
}
