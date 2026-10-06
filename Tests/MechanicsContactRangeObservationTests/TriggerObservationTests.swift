import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct TriggerObservationTests {
    @Test func actualEnterExitRetainsOriginalGeometryWithoutMutatingPrefix() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a",trigger:true),ContactRangeFixtures.recipe("b",body:"b")]
        let filters=CollisionFilterPolicy(jointExclusions:[],allowSameBody:false,user:nil)
        let firstScene=try ContactRangeFixtures.scene(model:model,recipes:recipes,x:3)
        let secondScene=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:1,x:0.99)
        let thirdScene=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:2,x:3)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        let observer:any ContactRangeObserving=ReferenceContactRangeObserver()
        let first=try observer.triggers(scene:firstScene,mount:mount,filters:filters,previous:nil,sampleIndex:0,policy:policy,collisionWork:&collision,work:&work)
        let second=try observer.triggers(scene:secondScene,mount:mount,filters:filters,previous:first,sampleIndex:1,policy:policy,collisionWork:&collision,work:&work)
        let third=try observer.triggers(scene:thirdScene,mount:mount,filters:filters,previous:second,sampleIndex:2,policy:policy,collisionWork:&collision,work:&work)
        #expect(first.witnesses.isEmpty && first.update.events.isEmpty)
        #expect(second.update.events.first?.phase == .entered && second.sampleIndex == 1 && second.timeSeconds == 1)
        #expect(ContactRangeFixtures.close(try #require(second.witnesses.first).separation,-0.01))
        #expect(third.update.events.first?.phase == .exited && third.witnesses.isEmpty && third.exitedWitnesses.count == 1)
        #expect(third.exitedWitnesses[0].pointA == second.witnesses[0].pointA)
        #expect(second.witnesses.count == 1 && first.update.state.intersections.isEmpty)
    }
    @Test func genuineFreshEquivalentModelCanAssociateButCopiedStampCannot() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a",trigger:true),ContactRangeFixtures.recipe("b",body:"b")]
        let filters=CollisionFilterPolicy(jointExclusions:[],allowSameBody:false,user:nil)
        let firstScene=try ContactRangeFixtures.scene(model:model,recipes:recipes,x:3)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        let observer=ReferenceContactRangeObserver()
        let first=try observer.triggers(scene:firstScene,mount:mount,filters:filters,previous:nil,sampleIndex:0,policy:policy,collisionWork:&collision,work:&work)
        let equivalent=try ContactRangeFixtures.scene(model:ContactRangeFixtures.model(),recipes:recipes,time:1)
        let second=try observer.triggers(scene:equivalent,mount:mount,filters:filters,previous:first,sampleIndex:1,policy:policy,collisionWork:&collision,work:&work)
        #expect(second.witnesses.count == 1)
        let foreign=try ContactRangeFixtures.scene(model:ContactRangeFixtures.model(mass:2),recipes:recipes,time:1)
        #expect(foreign.source.model.stamp == firstScene.source.model.stamp)
        do throws(ContactRangeObservationError) {
            _=try observer.triggers(scene:foreign,mount:mount,filters:filters,previous:first,sampleIndex:1,policy:policy,collisionWork:&collision,work:&work)
            Issue.record("Changed original inertia descriptor published a prefix")
        } catch { if case .staleSource=error {} else { Issue.record("Wrong refusal") } }
    }
    @Test func temporalSequenceAndChangedMountOrCatalogRefuse() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a",trigger:true),ContactRangeFixtures.recipe("b",body:"b")]
        let filters=CollisionFilterPolicy(jointExclusions:[],allowSameBody:false,user:nil)
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        let observer=ReferenceContactRangeObserver()
        let first=try observer.triggers(scene:scene,mount:mount,filters:filters,previous:nil,sampleIndex:0,policy:policy,collisionWork:&collision,work:&work)
        #expect(throws:ContactRangeObservationError.self) { try observer.triggers(scene:scene,mount:mount,filters:filters,previous:first,sampleIndex:1,policy:policy,collisionWork:&collision,work:&work) }
        let later=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:1)
        #expect(throws:ContactRangeObservationError.self) { try observer.triggers(scene:later,mount:mount,filters:filters,previous:first,sampleIndex:2,policy:policy,collisionWork:&collision,work:&work) }
        let changed=try ContactRangeFixtures.mount(offset:.unitY)
        #expect(throws:ContactRangeObservationError.self) { try observer.triggers(scene:later,mount:changed,filters:filters,previous:first,sampleIndex:1,policy:policy,collisionWork:&collision,work:&work) }
    }
}
