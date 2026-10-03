import MechanicsCollision
import MechanicsCore
import Testing

@Suite(.timeLimit(.minutes(1)))
struct DiscoveryTests {
    @Test func conservativeCandidatesContainIndependentExhaustiveIntersectionsAndSweeps() throws {
        let discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery()
        let proxies = try [
            CollisionFixtures.proxy("a",shape:.sphere(radius:1),position:Vector3(0,0,0)),
            CollisionFixtures.proxy("b",shape:.sphere(radius:0.1),position:Vector3(0.9,0,0)),
            CollisionFixtures.proxy("c",shape:.sphere(radius:10),position:Vector3(12,0,0)),
            CollisionFixtures.proxy("d",shape:.sphere(radius:0.01),position:Vector3(12,0,0)),
            CollisionFixtures.proxy("e",shape:.sphere(radius:1),position:Vector3(-20,0,0)),
        ]
        let snapshot = try CollisionSnapshot(proxies:proxies,revision:1)
        var work = try CollisionFixtures.work()
        let candidates = try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(),policy:CollisionFixtures.policy(),work:&work)
        for i in proxies.indices { for j in (i+1)..<proxies.count {
            guard case .sphere(let a) = proxies[i].geometry.shape,case .sphere(let b) = proxies[j].geometry.shape else { continue }
            let separation = try proxies[i].pose.translation.subtracting(proxies[j].pose.translation).magnitude()-a-b
            if separation <= 0 { #expect(try candidates.contains(CollisionPairKey(proxies[i].geometry.colliderID,proxies[j].geometry.colliderID))) }
        } }
        let intersections = try discovery.overlaps(snapshot:snapshot,filters:CollisionFixtures.filters(),policy:CollisionFixtures.policy(),work:&work)
        #expect(intersections.count == 2)
        let fast = CollisionFixtures.moved(proxies[4],try Vector3(20,0,0))
        let end = try CollisionSnapshot(proxies:Array(proxies[0..<4])+[fast],revision:2)
        let swept = try discovery.candidates(snapshot:snapshot,endpoint:end,filters:CollisionFixtures.filters(),policy:CollisionFixtures.policy(),work:&work)
        #expect(try swept.contains(CollisionPairKey(proxies[0].geometry.colliderID,fast.geometry.colliderID)))
        for i in 1..<candidates.count { #expect(!candidates[i].precedes(candidates[i-1])) }
    }

    @Test func filteringPrecedenceInvalidReferencesAndCapacity() throws {
        let discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery()
        let a = try CollisionFixtures.proxy("a",shape:.sphere(radius:1),body:"shared")
        let b = try CollisionFixtures.proxy("b",shape:.sphere(radius:1),body:"shared")
        let snapshot = try CollisionSnapshot(proxies:[a,b],revision:1)
        var work = try CollisionFixtures.work()
        let key = try CollisionPairKey(a.geometry.colliderID,b.geometry.colliderID)
        let sameBody = try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(sameBody:false,user:RejectingFilter()),policy:CollisionFixtures.policy(),work:&work)
        #expect(sameBody.isEmpty)
        let joint = try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(exclusions:[key],user:RejectingFilter()),policy:CollisionFixtures.policy(),work:&work)
        #expect(joint.isEmpty)
        let masked = try CollisionFixtures.proxy("masked",shape:.sphere(radius:1),layer:2,mask:2)
        let masks = try discovery.candidates(snapshot:CollisionSnapshot(proxies:[a,masked],revision:2),endpoint:nil,filters:CollisionFixtures.filters(user:RejectingFilter()),policy:CollisionFixtures.policy(),work:&work)
        #expect(masks.isEmpty)
        let custom = try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(user:DropFilter()),policy:CollisionFixtures.policy(),work:&work)
        #expect(custom.isEmpty)
        #expect(throws:CollisionError.invalidFilterReport) {
            try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(user:InvalidReportFilter()),policy:CollisionFixtures.policy(),work:&work)
        }
        let absent = try CollisionFixtures.proxy("absent",shape:.sphere(radius:1))
        let dangling = try CollisionPairKey(a.geometry.colliderID,absent.geometry.colliderID)
        #expect(throws:CollisionError.invalidReference) {
            try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(exclusions:[dangling]),policy:CollisionFixtures.policy(),work:&work)
        }
        var limited = try CollisionFixtures.work(records:0)
        #expect(throws:CollisionError.resourceLimit(resource:.records,limit:0)) {
            try discovery.candidates(snapshot:snapshot,endpoint:nil,filters:CollisionFixtures.filters(),policy:CollisionFixtures.policy(),work:&limited)
        }
        #expect(throws:CollisionError.invalidIdentity) { try CollisionSnapshot(proxies:[a,a],revision:1) }
    }

    @Test func sceneRayTiesAreDeterministic() throws {
        let discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery()
        let a = try CollisionFixtures.proxy("a",shape:.sphere(radius:1))
        let b = try CollisionFixtures.proxy("b",shape:.sphere(radius:1))
        var work = try CollisionFixtures.work()
        let hits = try discovery.rayHits(snapshot:CollisionSnapshot(proxies:[b,a],revision:1),
            ray:CollisionRay(origin:Vector3(-3,0,0),direction:.unitX,maximumDistance:10),
            policy:CollisionFixtures.policy(),work:&work)
        #expect(hits.count == 2 && hits[0].geometry.colliderID.key == "a" && hits[1].geometry.colliderID.key == "b")
        #expect(hits[0].distance == 2 && hits[1].distance == 2)
    }
}
