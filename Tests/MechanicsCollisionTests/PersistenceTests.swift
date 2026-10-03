import MechanicsCollision
import MechanicsCore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct PersistenceTests {
    @Test func slidingManifoldPreservesIDsMergesPrunesAndRejectsStalePose() throws {
        let geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries()
        let persistence: any CollisionPersisting = ValueCollisionPersistence()
        var work = try CollisionFixtures.work()
        let policy = try CollisionFixtures.policy()
        let manifoldPolicy = try CollisionManifoldPolicy(mergeDistance:0.01,breakingSeparation:0.1)
        let box = try CollisionFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)),position:Vector3(0,0,0.9))
        let plane = try CollisionFixtures.proxy("plane",shape:.halfSpace)
        let witness = try geometry.witness(first:box,second:plane,policy:policy,work:&work)
        let initial = try persistence.manifold(first:box,second:plane,current:[witness,witness],previous:nil,
            manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&work)
        #expect(initial.contacts.count == 1 && initial.contacts[0].id == 0)
        let slid = CollisionFixtures.moved(box,try Vector3(0.7,0.2,0.9))
        let newWitness = try geometry.witness(first:slid,second:plane,policy:policy,work:&work)
        let continued = try persistence.manifold(first:slid,second:plane,current:[newWitness],previous:initial,
            manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&work)
        #expect(continued.contacts[0].id == initial.contacts[0].id)
        #expect(continued.nextContactID == initial.nextContactID)
        #expect(initial.contacts[0].witness.pointA == witness.pointA)
        #expect(throws:CollisionError.staleGeometry) {
            try persistence.manifold(first:slid,second:plane,current:[witness],previous:initial,
                manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&work)
        }
        let raised = CollisionFixtures.moved(box,try Vector3(0,0,3))
        let separated = try geometry.witness(first:raised,second:plane,policy:policy,work:&work)
        let pruned = try persistence.manifold(first:raised,second:plane,current:[separated],previous:initial,
            manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&work)
        #expect(pruned.contacts.isEmpty)
        let edited = try CollisionFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)),position:Vector3(0,0,0.9),sourceRevision:2)
        #expect(throws:CollisionError.staleGeometry) {
            try persistence.manifold(first:edited,second:plane,current:[],previous:initial,
                manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&work)
        }
        var limited = try CollisionFixtures.work(records:0)
        #expect(throws:CollisionError.resourceLimit(resource:.records,limit:0)) {
            try persistence.manifold(first:box,second:plane,current:[witness],previous:nil,
                manifoldPolicy:manifoldPolicy,queryPolicy:policy,work:&limited)
        }
    }

    @Test func sampledTriggerPassThroughHasOrderedEnterExitAndValueState() throws {
        let persistence: any CollisionPersisting = ValueCollisionPersistence()
        var work = try CollisionFixtures.work()
        let trigger = try CollisionFixtures.proxy("sensor",shape:.sphere(radius:1),trigger:true)
        let moving = try CollisionFixtures.proxy("moving",shape:.sphere(radius:0.25),position:Vector3(3,0,0))
        let filters = CollisionFixtures.filters(), policy = try CollisionFixtures.policy()
        let first = try persistence.triggers(snapshot:CollisionSnapshot(proxies:[trigger,moving],revision:1),
            filters:filters,previous:nil,sampleIndex:0,policy:policy,work:&work)
        #expect(first.events.isEmpty && first.state.intersections.isEmpty)
        let inside = CollisionFixtures.moved(moving,try Vector3(0.5,0,0))
        let second = try persistence.triggers(snapshot:CollisionSnapshot(proxies:[inside,trigger],revision:2),
            filters:filters,previous:first.state,sampleIndex:1,policy:policy,work:&work)
        #expect(second.events.count == 1 && second.events[0].phase == .entered)
        #expect(second.events[0].sampleIndex == 1)
        let out = CollisionFixtures.moved(moving,try Vector3(-3,0,0))
        let third = try persistence.triggers(snapshot:CollisionSnapshot(proxies:[trigger,out],revision:3),
            filters:filters,previous:second.state,sampleIndex:2,policy:policy,work:&work)
        #expect(third.events.count == 1 && third.events[0].phase == .exited)
        #expect(third.events[0].sampleIndex == 2)
        #expect(third.state.intersections.isEmpty)
        #expect(second.state.intersections.count == 1)
        #expect(throws:CollisionError.invalidLifecycle) {
            try persistence.triggers(snapshot:CollisionSnapshot(proxies:[trigger,out],revision:3),
                filters:filters,previous:second.state,sampleIndex:4,policy:policy,work:&work)
        }
        let changed = try CollisionFixtures.proxy("sensor",shape:.sphere(radius:1.1),geometryRevision:2,trigger:true)
        #expect(throws:CollisionError.staleGeometry) {
            try persistence.triggers(snapshot:CollisionSnapshot(proxies:[changed,out],revision:4),
                filters:filters,previous:second.state,sampleIndex:2,policy:policy,work:&work)
        }
    }
}
