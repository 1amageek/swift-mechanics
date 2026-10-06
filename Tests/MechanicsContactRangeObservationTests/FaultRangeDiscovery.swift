import SwiftMechanics

struct FaultRangeDiscovery: CollisionDiscovering {
    enum Mode:Sendable { case foreignPose,resetSuccess,resetFailure,budgetReplacement,plainFailure,cancel }
    let mode:Mode
    let cancel:@Sendable ()->Void
    init(_ mode:Mode,cancel:@escaping @Sendable ()->Void = {}) { self.mode=mode;self.cancel=cancel }
    func candidates(snapshot:CollisionSnapshot,endpoint:CollisionSnapshot?,filters:CollisionFilterPolicy,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->[CollisionPairKey] {
        try ExhaustiveCollisionDiscovery().candidates(snapshot:snapshot,endpoint:endpoint,filters:filters,policy:policy,work:&work)
    }
    func overlaps(snapshot:CollisionSnapshot,filters:CollisionFilterPolicy,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->[CollisionWitness] {
        try ExhaustiveCollisionDiscovery().overlaps(snapshot:snapshot,filters:filters,policy:policy,work:&work)
    }
    func rayHits(snapshot:CollisionSnapshot,ray:CollisionRay,policy:CollisionQueryPolicy,work:inout CollisionWork) throws(CollisionError)->[CollisionRayHit] {
        let queried:CollisionSnapshot
        if mode == .foreignPose {
            let shifted=try snapshot.proxies.map { proxy throws(CollisionError) in
                let translation:Vector3
                do throws(CoreError) { translation=try proxy.pose.translation.adding(.unitX) } catch { throw .core(error) }
                return proxy.moved(to:RigidTransform(rotation:proxy.pose.rotation,translation:translation))
            }
            queried=try CollisionSnapshot(proxies:shifted,revision:snapshot.revision)
        } else { queried=snapshot }
        let result=try ExhaustiveCollisionDiscovery().rayHits(snapshot:queried,ray:ray,policy:policy,work:&work)
        switch mode {
        case .resetSuccess: work=CollisionWork(budget:work.budget)
        case .resetFailure: work=CollisionWork(budget:work.budget);throw .unsupportedQuery
        case .budgetReplacement:
            work=CollisionWork(budget:try CollisionBudget(scalarStorage:work.budget.scalarStorage,operations:work.budget.operations+1,iterations:work.budget.iterations,records:work.budget.records))
            try work.charge(100)
        case .plainFailure: throw .unsupportedQuery
        case .cancel: cancel()
        case .foreignPose: break
        }
        return result
    }
}
