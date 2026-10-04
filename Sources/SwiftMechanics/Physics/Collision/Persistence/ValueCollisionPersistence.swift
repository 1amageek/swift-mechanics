
public struct ValueCollisionPersistence: CollisionPersisting, Sendable {
    public init() {}

    public func manifold(first: CollisionProxy, second: CollisionProxy, current: [CollisionWitness],
                         previous: CollisionManifold?, manifoldPolicy: CollisionManifoldPolicy,
                         queryPolicy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionManifold {
        let pair = try CollisionPairIdentity(first:first.geometry,second:second.geometry)
        try queryPolicy.validate(first); try queryPolicy.validate(second)
        if let previous, previous.pair != pair { throw .staleGeometry }
        let oldCount = previous?.contacts.count ?? 0
        let capacity = min(current.count,work.budget.records)
        let storage = try CollisionWork.sum(256,CollisionWork.sum(CollisionWork.product(128,current.count),
            CollisionWork.sum(CollisionWork.product(256,oldCount),CollisionWork.product(256,capacity))))
        try work.requireStorage(storage)
        var merged = [CollisionWitness](); merged.reserveCapacity(capacity)
        for candidate in current {
            try work.charge(64)
            guard candidate.pair == pair, candidate.poseA == first.pose, candidate.poseB == second.pose else { throw .staleGeometry }
            guard candidate.originalBalanceResidual <= queryPolicy.lengthTolerance else { throw .geometricResidual(value:candidate.originalBalanceResidual,threshold:queryPolicy.lengthTolerance) }
            if candidate.separation > manifoldPolicy.breakingSeparation { continue }
            var match: Int? = nil
            for i in merged.indices {
                try work.charge(256)
                if try matches(candidate,merged[i],distance:manifoldPolicy.mergeDistance) { match = i; break }
            }
            if let match {
                if candidate.separation < merged[match].separation || (candidate.separation == merged[match].separation && precedes(candidate,merged[match])) { merged[match] = candidate }
            } else {
                try work.requireRecords(CollisionWork.sum(merged.count,1)); merged.append(candidate)
            }
        }
        // Bounded in-place insertion sort establishes input-order independence.
        for i in merged.indices {
            var j = i
            while j > 0 {
                try work.charge(32)
                if !precedes(merged[j],merged[j-1]) { break }
                merged.swapAt(j,j-1); j -= 1
            }
        }
        var used = [Bool](repeating:false,count:oldCount)
        var result = [CollisionManifoldContact](); result.reserveCapacity(merged.count)
        var nextID = previous?.nextContactID ?? 0
        for witness in merged {
            var oldIndex: Int? = nil
            if let previous {
                for i in previous.contacts.indices where !used[i] {
                    try work.charge(256)
                    if try matches(witness,previous.contacts[i].witness,distance:manifoldPolicy.mergeDistance) {
                        if let existing = oldIndex {
                            if previous.contacts[i].id < previous.contacts[existing].id { oldIndex = i }
                        } else { oldIndex = i }
                    }
                }
            }
            let id: UInt64
            if let oldIndex, let previous { used[oldIndex] = true; id = previous.contacts[oldIndex].id }
            else {
                let (next,overflow) = nextID.addingReportingOverflow(1)
                guard !overflow else { throw .invalidLifecycle }
                id = nextID; nextID = next
            }
            result.append(CollisionManifoldContact(id:id,witness:witness))
        }
        return CollisionManifold(pair:pair,contacts:result,nextContactID:nextID)
    }

    public func triggers(snapshot: CollisionSnapshot, filters: CollisionFilterPolicy,
                         previous: CollisionTriggerState?, sampleIndex: UInt64,
                         policy: CollisionQueryPolicy, work: inout CollisionWork) throws(CollisionError) -> CollisionTriggerUpdate {
        try work.checkCancellation()
        if let previous {
            let (next,overflow) = previous.sampleIndex.addingReportingOverflow(1)
            guard !overflow, next == sampleIndex else { throw .invalidLifecycle }
        } else if sampleIndex != 0 { throw .invalidLifecycle }
        let n = snapshot.proxies.count
        let capacity = min(work.budget.records,try CollisionWork.product(n,max(0,n-1))/2)
        let previousCount = previous?.intersections.count ?? 0
        try work.requireStorage(CollisionWork.sum(256,CollisionWork.sum(CollisionWork.product(70,n),
            CollisionWork.sum(CollisionWork.product(128,previousCount),CollisionWork.product(272,capacity)))))
        if let previous {
            for identity in previous.intersections {
                try work.charge(CollisionWork.product(2,n))
                let a = try snapshot.proxy(for:identity.first.colliderID), b = try snapshot.proxy(for:identity.second.colliderID)
                guard a.geometry == identity.first, b.geometry == identity.second else { throw .staleGeometry }
            }
        }
        let discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery()
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let candidates = try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:filters,policy:policy,work:&work)
        var intersections = [CollisionPairIdentity](); intersections.reserveCapacity(capacity)
        for pair in candidates {
            try work.charge(CollisionWork.product(2,n))
            let a = try snapshot.proxy(for:pair.first), b = try snapshot.proxy(for:pair.second)
            if !a.filter.isTrigger && !b.filter.isTrigger { continue }
            let witness = try geometry.witness(first:a,second:b,policy:policy,work:&work)
            if witness.separation <= 0 {
                try work.requireRecords(CollisionWork.sum(intersections.count,1)); intersections.append(witness.pair)
            }
        }
        var events = [CollisionTriggerEvent]()
        events.reserveCapacity(min(work.budget.records,try CollisionWork.sum(previousCount,intersections.count)))
        let old = previous?.intersections ?? []
        var i = 0, j = 0
        while i < old.count || j < intersections.count {
            try work.charge(64)
            if i < old.count && j < intersections.count {
                let a = try old[i].key(), b = try intersections[j].key()
                if a == b { i += 1; j += 1; continue }
                if a.precedes(b) {
                    try work.requireRecords(CollisionWork.sum(events.count,1))
                    events.append(CollisionTriggerEvent(pair:old[i],phase:.exited,sampleIndex:sampleIndex)); i += 1
                } else {
                    try work.requireRecords(CollisionWork.sum(events.count,1))
                    events.append(CollisionTriggerEvent(pair:intersections[j],phase:.entered,sampleIndex:sampleIndex)); j += 1
                }
            } else if i < old.count {
                try work.requireRecords(CollisionWork.sum(events.count,1))
                events.append(CollisionTriggerEvent(pair:old[i],phase:.exited,sampleIndex:sampleIndex)); i += 1
            } else {
                try work.requireRecords(CollisionWork.sum(events.count,1))
                events.append(CollisionTriggerEvent(pair:intersections[j],phase:.entered,sampleIndex:sampleIndex)); j += 1
            }
        }
        return CollisionTriggerUpdate(state:CollisionTriggerState(intersections:intersections,sampleIndex:sampleIndex),events:events)
    }

    private func matches(_ a: CollisionWitness,_ b: CollisionWitness,distance:Double) throws(CollisionError) -> Bool {
        if a.featureA == b.featureA && a.featureB == b.featureB { return true }
        return try collisionCore { () throws(CoreError) in
            let firstDistance = try a.pointA.subtracting(b.pointA).magnitude()
            if firstDistance > distance { return false }
            let secondDistance = try a.pointB.subtracting(b.pointB).magnitude()
            return secondDistance <= distance
        }
    }

    private func precedes(_ a: CollisionWitness,_ b: CollisionWitness) -> Bool {
        if a.featureA.orderCode != b.featureA.orderCode { return a.featureA.orderCode < b.featureA.orderCode }
        if a.featureB.orderCode != b.featureB.orderCode { return a.featureB.orderCode < b.featureB.orderCode }
        if a.pointA.x != b.pointA.x { return a.pointA.x < b.pointA.x }
        if a.pointA.y != b.pointA.y { return a.pointA.y < b.pointA.y }
        return a.pointA.z < b.pointA.z
    }
}
