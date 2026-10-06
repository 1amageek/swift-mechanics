import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct RangeObservationTests {
    @Test func actualMountedSphereHitsAndCommonRotation() throws {
        for rotation in [UnitQuaternion.identity,try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7)] {
            let model=try ContactRangeFixtures.model(rotation:rotation)
            let recipe=try ContactRangeFixtures.recipe("target",body:"b",shape:.sphere(radius:1))
            let scene=try ContactRangeFixtures.scene(model:model,recipes:[recipe],x:3)
            let policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
            var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
            let observer:any ContactRangeObserving=ReferenceContactRangeObserver()
            let result=try observer.range(scene:scene,mount:mount,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),
                targets:[recipe.colliderID],policy:policy,collisionWork:&collision,work:&work)
            #expect(result.hits.count == 1 && result.scene === scene)
            let hit=try #require(result.hits.first)
            #expect(ContactRangeFixtures.close(hit.distance,2))
            #expect(try ContactRangeFixtures.close(hit.point,rotation.rotating(Vector3(2,0,0))))
            #expect(try ContactRangeFixtures.close(hit.outwardNormal,rotation.rotating(Vector3(-1,0,0))))
            #expect(hit.geometry.resolution == .analytic && hit.geometry.approximationError == 0)
            #expect(result.timeSeconds == 0 && result.expressedFrame == model.tree.worldFrame)
            #expect(work.operations > 0 && collision.operations > 0)
        }
    }
    @Test func missesInsideGrazingLimitsAndUnsupportedAreDistinct() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let sphere=try ContactRangeFixtures.recipe("sphere",body:"a",shape:.sphere(radius:1))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[sphere])
        let observer:any ContactRangeObserving=ReferenceContactRangeObserver()
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        let inside=try observer.range(scene:scene,mount:mount,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),targets:[sphere.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(inside.hits.first?.distance == 1)
        let grazing=try observer.range(scene:scene,mount:mount,ray:CollisionRay(origin:Vector3(-3,1,0),direction:.unitX,maximumDistance:10),targets:[sphere.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(grazing.hits.first?.distance == 3)
        let miss=try observer.range(scene:scene,mount:mount,ray:CollisionRay(origin:Vector3(-3,2,0),direction:.unitX,maximumDistance:10),targets:[sphere.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(miss.hits.isEmpty)
        let limited=try observer.range(scene:scene,mount:mount,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:0.5),targets:[sphere.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(limited.hits.isEmpty)
        let rounded=try ContactRangeFixtures.recipe("box",body:"a",shape:.box(halfExtents:Vector3(1,1,1)),margin:0.1)
        let unsupported=try ContactRangeFixtures.scene(model:model,recipes:[rounded])
        #expect(throws:ContactRangeObservationError.self) {
            try observer.range(scene:unsupported,mount:mount,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),targets:[rounded.colliderID],policy:policy,collisionWork:&collision,work:&work)
        }
    }
    @Test func movingColliderOffsetAndSortedIdentitySelection() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let first=try ContactRangeFixtures.recipe("near",body:"b",shape:.sphere(radius:0.5),offset:Vector3(1,0,0))
        let second=try ContactRangeFixtures.recipe("far",body:"a",shape:.sphere(radius:0.5),offset:Vector3(4,0,0))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[second,first],x:1,angle:Double.pi/2)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        let result=try ReferenceContactRangeObserver().range(scene:scene,mount:mount,ray:CollisionRay(origin:Vector3(0,1,0),direction:.unitX,maximumDistance:10),
            targets:[first.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(ContactRangeFixtures.close(try #require(result.hits.first).distance,0.5))
        #expect(try ContactRangeFixtures.close(scene.collision.proxies[1].pose.translation,Vector3(1,1,0)))
        let orderedScene=try ContactRangeFixtures.scene(model:model,recipes:[second,first],x:1)
        let ordered=try ReferenceContactRangeObserver().range(scene:orderedScene,mount:mount,ray:CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10),targets:[second.colliderID,first.colliderID],policy:policy,collisionWork:&collision,work:&work)
        #expect(ordered.hits.map(\.geometry.colliderID) == [first.colliderID,second.colliderID])
    }
}
