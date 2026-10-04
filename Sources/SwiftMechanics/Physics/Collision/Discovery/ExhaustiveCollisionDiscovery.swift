
public struct ExhaustiveCollisionDiscovery: CollisionDiscovering, Sendable {
    public init() {}

    public func candidates(snapshot: CollisionSnapshot, endpoint: CollisionSnapshot?, filters: CollisionFilterPolicy,
                           policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionPairKey] {
        let n = snapshot.proxies.count
        let capacity = min(work.budget.records,try CollisionWork.product(n,max(0,n-1))/2)
        try work.requireStorage(CollisionWork.sum(CollisionWork.product(70,n),CollisionWork.product(16,capacity)))
        try work.charge(CollisionWork.sum(CollisionWork.product(8,CollisionWork.product(n,n)),CollisionWork.product(CollisionWork.product(8,filters.jointExclusions.count),n)))
        for excluded in filters.jointExclusions {
            _ = try snapshot.proxy(for: excluded.first); _ = try snapshot.proxy(for: excluded.second)
        }
        if let endpoint {
            guard endpoint.proxies.count == n else { throw .staleGeometry }
        }
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var bounds = [CollisionBounds]()
        bounds.reserveCapacity(n)
        for proxy in snapshot.proxies {
            try work.checkCancellation(); try policy.validate(proxy)
            let start = try geometry.bounds(proxy:proxy,work:&work)
            if let endpoint {
                let end = try endpoint.proxy(for:proxy.geometry.colliderID)
                guard end.geometry == proxy.geometry, end.filter == proxy.filter else { throw .staleGeometry }
                guard end.pose.rotation == proxy.pose.rotation || end.pose.rotation == proxy.pose.rotation.negated() else { throw .unsupportedSweep }
                bounds.append(try start.union(geometry.bounds(proxy:end,work:&work)))
            } else { bounds.append(start) }
        }
        var result = [CollisionPairKey]()
        result.reserveCapacity(capacity)
        for i in 0..<n {
            for j in (i+1)..<n {
                try work.charge(CollisionWork.sum(32,CollisionWork.product(8,filters.jointExclusions.count)))
                let a = snapshot.proxies[i], b = snapshot.proxies[j]
                let key = try CollisionPairKey(a.geometry.colliderID,b.geometry.colliderID)
                if !a.filter.enabled || !b.filter.enabled { continue }
                if a.filter.layerBits & b.filter.maskBits == 0 || b.filter.layerBits & a.filter.maskBits == 0 { continue }
                if filters.jointExclusions.contains(key) { continue }
                if !filters.allowSameBody && a.geometry.bodyID == b.geometry.bodyID { continue }
                if let user = filters.user {
                    let remaining = work.budget.operations-work.operations
                    let decision = try user.decide(first:a,second:b,remainingOperations:remaining)
                    guard decision.operations > 0, decision.operations <= remaining else { throw .invalidFilterReport }
                    try work.charge(decision.operations)
                    if !decision.allowed { continue }
                }
                if !bounds[i].overlaps(bounds[j]) { continue }
                try work.requireRecords(CollisionWork.sum(result.count,1))
                try work.charge(CollisionWork.product(8,CollisionWork.sum(result.count,1)))
                var index = result.count
                while index > 0 && key.precedes(result[index-1]) { index -= 1 }
                result.insert(key,at:index)
            }
        }
        return result
    }

    public func overlaps(snapshot: CollisionSnapshot, filters: CollisionFilterPolicy,
                         policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionWitness] {
        let n = snapshot.proxies.count
        let capacity = min(work.budget.records,try CollisionWork.product(n,max(0,n-1))/2)
        try work.requireStorage(CollisionWork.sum(CollisionWork.product(70,n),CollisionWork.product(144,capacity)))
        let pairs = try candidates(snapshot:snapshot,endpoint:nil,filters:filters,policy:policy,work:&work)
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var result = [CollisionWitness]()
        result.reserveCapacity(min(pairs.count,work.budget.records))
        for pair in pairs {
            try work.charge(CollisionWork.product(2,snapshot.proxies.count))
            let witness = try geometry.witness(first:snapshot.proxy(for:pair.first),second:snapshot.proxy(for:pair.second),policy:policy,work:&work)
            if witness.separation <= 0 {
                try work.requireRecords(CollisionWork.sum(result.count,1)); result.append(witness)
            }
        }
        return result
    }

    public func rayHits(snapshot: CollisionSnapshot, ray: CollisionRay,
                        policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> [CollisionRayHit] {
        let capacity = min(snapshot.proxies.count,work.budget.records)
        try work.requireStorage(CollisionWork.sum(CollisionWork.product(64,snapshot.proxies.count),CollisionWork.product(64,capacity)))
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        var result = [CollisionRayHit]()
        result.reserveCapacity(min(snapshot.proxies.count,work.budget.records))
        for proxy in snapshot.proxies {
            if !proxy.filter.enabled { continue }
            if let hit = try geometry.ray(proxy:proxy,ray:ray,policy:policy,work:&work) {
                try work.requireRecords(CollisionWork.sum(result.count,1)); try work.charge(CollisionWork.product(16,CollisionWork.sum(result.count,1)))
                var index = result.count
                while index > 0 && (hit.distance < result[index-1].distance ||
                    (hit.distance == result[index-1].distance && hit.geometry.colliderID.key < result[index-1].geometry.colliderID.key)) { index -= 1 }
                result.insert(hit,at:index)
            }
        }
        return result
    }
}
