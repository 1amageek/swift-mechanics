/// Inject a qualified supplier; AnalyticCollisionQueries is the selected source domain.
public struct BoundedCompoundCollisionQueries<Geometry: CollisionGeometryQuerying>: CompoundCollisionQuerying, Sendable {
    public let geometry: Geometry
    public init(geometry: Geometry) { self.geometry = geometry }

    public func closest(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                        filters: CollisionFilterPolicy, policy: CollisionQueryPolicy,
                        work: inout CollisionWork) throws(CompoundCollisionError) -> CompoundCollisionWitness? {
        let retained = try admit(first: first, second: second, filters: filters, work: &work)
        try CompoundCollisionAccounting.storage(children: retained, outputs: 2, work: &work)
        let a = try transformed(first, policy: policy, work: &work)
        let b = try transformed(second, policy: policy, work: &work)
        var best: CompoundCollisionWitness?
        for i in a.indices { for j in b.indices {
            if try allowed(first: first, second: second, a: a[i], b: b[j], filters: filters, work: &work) {
                let value = try witness(first: first, second: second, a: a[i], b: b[j],
                                        i: i, j: j, policy: policy, work: &work)
                if let previous = best {
                    if value.witness.separation < previous.witness.separation { best = value }
                } else { best = value }
            }
        } }
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        return best
    }

    public func overlaps(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                         filters: CollisionFilterPolicy, policy: CollisionQueryPolicy,
                         work: inout CollisionWork) throws(CompoundCollisionError) -> [CompoundCollisionWitness] {
        let retained = try admit(first: first, second: second, filters: filters, work: &work)
        let capacity = try CompoundCollisionAccounting.run { () throws(CollisionError) in
            min(work.budget.records, try CollisionWork.product(first.compound.children.count, second.compound.children.count))
        }
        let retainedOutputs = try CompoundCollisionAccounting.run { () throws(CollisionError) in try CollisionWork.sum(capacity, 1) }
        try CompoundCollisionAccounting.storage(children: retained, outputs: retainedOutputs, work: &work)
        let a = try transformed(first, policy: policy, work: &work)
        let b = try transformed(second, policy: policy, work: &work)
        var result = [CompoundCollisionWitness]()
        result.reserveCapacity(capacity)
        for i in a.indices { for j in b.indices {
            if try allowed(first: first, second: second, a: a[i], b: b[j], filters: filters, work: &work) {
                let value = try witness(first: first, second: second, a: a[i], b: b[j],
                                        i: i, j: j, policy: policy, work: &work)
                if value.witness.separation <= 0 {
                    try CompoundCollisionAccounting.run { () throws(CollisionError) in
                        try work.requireRecords(CollisionWork.sum(result.count, 1)); try work.charge(256)
                    }
                    result.append(value)
                }
            }
        } }
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        return result
    }

    public func rayHits(placement: CompoundCollisionPlacement, ray: CollisionRay, policy: CollisionQueryPolicy,
                        work: inout CollisionWork) throws(CompoundCollisionError) -> [CompoundCollisionRayHit] {
        let n = placement.compound.children.count
        let capacity = min(n, work.budget.records)
        let retainedOutputs = try CompoundCollisionAccounting.run { () throws(CollisionError) in try CollisionWork.sum(capacity, 1) }
        try CompoundCollisionAccounting.storage(children: n, outputs: retainedOutputs, work: &work)
        let children = try transformed(placement, policy: policy, work: &work)
        var result = [CompoundCollisionRayHit]()
        result.reserveCapacity(capacity)
        for i in children.indices {
            try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(16) }
            if !placement.filter.enabled || !children[i].filter.enabled { continue }
            let next = try CompoundCollisionAccounting.run { () throws(CollisionError) in try CollisionWork.sum(result.count, 1) }
            let id = children[i].geometry.colliderID
            if let hit = try CompoundCollisionAccounting.child(first: id, second: nil, {
                () throws(CollisionError) in try geometry.ray(proxy: children[i], ray: ray, policy: policy, work: &work)
            }) {
                guard hit.geometry == children[i].geometry else { throw .child(first: id, second: nil, cause: .staleGeometry) }
                let value = CompoundCollisionRayHit(placement: placement, localChild: placement.compound.children[i], hit: hit)
                try CompoundCollisionAccounting.run { () throws(CollisionError) in
                    try work.requireRecords(next); try work.charge(CollisionWork.sum(64, CollisionWork.product(64, next)))
                }
                var index = result.count
                while index > 0 && (hit.distance < result[index - 1].hit.distance ||
                    (hit.distance == result[index - 1].hit.distance && id.key < result[index - 1].hit.geometry.colliderID.key)) { index -= 1 }
                result.insert(value, at: index)
            }
        }
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        return result
    }

    private func transformed(_ placement: CompoundCollisionPlacement, policy: CollisionQueryPolicy,
                             work: inout CollisionWork) throws(CompoundCollisionError) -> [CollisionProxy] {
        var result = [CollisionProxy]()
        result.reserveCapacity(placement.compound.children.count)
        for child in placement.compound.children {
            let g = child.geometry
            try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(128) }
            try CompoundCollisionAccounting.child(first: g.colliderID, second: nil, {
                () throws(CollisionError) in try policy.validate(child)
            })
            let pose: RigidTransform
            do { pose = try placement.pose.composed(with: child.pose) } catch { throw .core(error) }
            let representations: BodyRepresentations
            do { representations = try BodyRepresentations(collisionGeometry: g.representation) } catch { throw .model(error) }
            let world = try CompoundCollisionAccounting.child(first: g.colliderID, second: nil, {
                () throws(CollisionError) in try CollisionProxy(colliderID: g.colliderID, bodyID: g.bodyID,
                    frameID: placement.frameID, geometryRevision: g.geometryRevision, frameRevision: placement.frameRevision,
                    shape: g.shape, margin: g.margin, representations: representations,
                    expectedSourceRevision: g.representation.provenance.revision, resolution: g.resolution,
                    pose: pose, filter: child.filter)
            })
            result.append(world)
        }
        return result
    }

    private func admit(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                       filters: CollisionFilterPolicy, work: inout CollisionWork) throws(CompoundCollisionError) -> Int {
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.checkCancellation() }
        guard first.frameID == second.frameID, first.frameRevision == second.frameRevision else { throw .frameMismatch }
        guard first.compound.identity.colliderID != second.compound.identity.colliderID else { throw .invalidIdentity }
        let a = first.compound.children, b = second.compound.children
        let n = try CompoundCollisionAccounting.run { () throws(CollisionError) in try CollisionWork.sum(a.count, b.count) }
        try CompoundCollisionAccounting.storage(children: n, outputs: 0, work: &work)
        for child in a {
            guard child.geometry.colliderID != second.compound.identity.colliderID else { throw .invalidIdentity }
            for other in b {
                try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
                guard child.geometry.colliderID != other.geometry.colliderID else { throw .invalidIdentity }
            }
        }
        for child in b {
            try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
            guard child.geometry.colliderID != first.compound.identity.colliderID else { throw .invalidIdentity }
        }
        for i in filters.jointExclusions.indices {
            let excluded = filters.jointExclusions[i]
            for key in [excluded.first.key, excluded.second.key] {
                for _ in key.utf8 {
                    try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(1) }
                }
            }
            var foundA = false, foundB = false
            for child in a {
                try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
                if child.geometry.colliderID == excluded.first { foundA = true }
                if child.geometry.colliderID == excluded.second { foundB = true }
            }
            for child in b {
                try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
                if child.geometry.colliderID == excluded.first { foundA = true }
                if child.geometry.colliderID == excluded.second { foundB = true }
            }
            guard foundA, foundB else { throw .collision(.invalidReference) }
            for j in 0..<i {
                try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
                guard excluded != filters.jointExclusions[j] else { throw .invalidIdentity }
            }
        }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Custom compound filtering lacks a qualified failure-work
        // receipt. Public closest/overlaps refuse it before dispatch; support requires actual callback
        // failure consumption and budget/cancellation fixtures, not a successful decision alone.
        if let _ = filters.user { throw .unsupportedUserFilterAccounting }
        return n
    }

    private func allowed(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                         a: CollisionProxy, b: CollisionProxy, filters: CollisionFilterPolicy,
                         work: inout CollisionWork) throws(CompoundCollisionError) -> Bool {
        try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(32) }
        if !first.filter.enabled || !second.filter.enabled { return false }
        if first.filter.layerBits & second.filter.maskBits == 0 || second.filter.layerBits & first.filter.maskBits == 0 { return false }
        if !a.filter.enabled || !b.filter.enabled { return false }
        if a.filter.layerBits & b.filter.maskBits == 0 || b.filter.layerBits & a.filter.maskBits == 0 { return false }
        let key = try CompoundCollisionAccounting.run { () throws(CollisionError) in try CollisionPairKey(a.geometry.colliderID, b.geometry.colliderID) }
        for excluded in filters.jointExclusions {
            try CompoundCollisionAccounting.run { () throws(CollisionError) in try work.charge(8) }
            if excluded == key { return false }
        }
        if !filters.allowSameBody && a.geometry.bodyID == b.geometry.bodyID { return false }
        return true
    }

    private func witness(first: CompoundCollisionPlacement, second: CompoundCollisionPlacement,
                         a: CollisionProxy, b: CollisionProxy, i: Int, j: Int,
                         policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CompoundCollisionError) -> CompoundCollisionWitness {
        let value = try CompoundCollisionAccounting.child(first: a.geometry.colliderID, second: b.geometry.colliderID, {
            () throws(CollisionError) in try geometry.witness(first: a, second: b, policy: policy, work: &work)
        })
        guard value.pair.first == a.geometry, value.pair.second == b.geometry,
              value.poseA == a.pose, value.poseB == b.pose else {
            throw .child(first: a.geometry.colliderID, second: b.geometry.colliderID, cause: .staleGeometry)
        }
        return CompoundCollisionWitness(first: first, second: second,
            firstLocalChild: first.compound.children[i], secondLocalChild: second.compound.children[j], witness: value)
    }
}
