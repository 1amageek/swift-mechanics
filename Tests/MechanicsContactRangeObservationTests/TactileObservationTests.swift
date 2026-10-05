import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct TactileObservationTests {
    @Test func virginActualGeometryForceEnergyAndIssuedHistoryAreContinuous() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a"),ContactRangeFixtures.recipe("b",body:"b")]
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes)
        let binding=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair())
        let mount=try ContactRangeFixtures.mount("b")
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision(),contact=try ContactRangeFixtures.contact()
        let observer:any ContactRangeObserving=ReferenceContactRangeObserver()
        let sample=try observer.tactile(scene:scene,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        #expect(ContactRangeFixtures.close(sample.witness.separation,-0.01))
        #expect(try ContactRangeFixtures.close(sample.applicationPoint,Vector3(0.495,0,0)))
        #expect(try ContactRangeFixtures.close(sample.force,Vector3(10,0,0)))
        #expect(ContactRangeFixtures.close(sample.response.normalStoredEnergy,0.05))
        #expect(sample.response.acceptedHistory == binding.accepted && sample.temporalMeaning == .instantaneousContinuous)
        let later=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:1)
        let issued=try ContactRangeFixtures.binding(scene:later,pair:ContactRangeFixtures.pair(friction:true),issued:true)
        let held=try observer.tactile(scene:later,mount:mount,contact:issued,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        #expect(ContactRangeFixtures.close(held.response.tangentialForceFirst,-1))
        #expect(ContactRangeFixtures.close(held.response.tangentialStoredEnergy,0.0005))
        #expect(held.response.acceptedHistory == issued.accepted && issued.accepted.sequence == 1)
        #expect(held.response.originalPowerResidual <= 1e-9 && held.response.originalRatePowerResidual <= 1e-9)
    }
    @Test func actualOffsetRatesActionReactionReferenceShiftAndRotation() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a",offset:.unitY),ContactRangeFixtures.recipe("b",body:"b",offset:.unitY)]
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes,velocity:[0,2,3])
        let binding=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair())
        let first=try ContactRangeFixtures.mount(),second=try ContactRangeFixtures.mount("b")
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision(),contact=try ContactRangeFixtures.contact()
        let observer=ReferenceContactRangeObserver()
        let a=try observer.tactile(scene:scene,mount:first,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        let b=try observer.tactile(scene:scene,mount:second,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        #expect(try ContactRangeFixtures.close(b.relativeVelocity,Vector3(-3,0.515,0)))
        #expect(try ContactRangeFixtures.close(b.relativeAngularVelocity,Vector3(0,0,3)))
        #expect(try ContactRangeFixtures.close(a.force,Vector3(-10,0,0)))
        #expect(try ContactRangeFixtures.close(b.force,Vector3(10,0,0)))
        #expect(try ContactRangeFixtures.close(a.couple,Vector3(0,0,10)))
        #expect(try ContactRangeFixtures.close(b.couple,Vector3(0,0,-10)))
        #expect(ContactRangeFixtures.close(b.response.relativeMechanicalPower,-30))
        #expect(ContactRangeFixtures.close(b.response.elasticPotentialRatePower,30))
        let rotation=try UnitQuaternion(axis:.unitZ,angle:Double.pi/2)
        let mounted=try ContactRangeFixtures.mount("b",offset:.unitY,rotation:rotation)
        let rotated=try observer.tactile(scene:scene,mount:mounted,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        #expect(try ContactRangeFixtures.close(rotated.force,Vector3(0,-10,0)))
        #expect(try ContactRangeFixtures.close(rotated.couple,.zero))
        #expect(rotated.expressedFrame == mounted.sensorFrame && binding.accepted.sequence == 0)
    }
    @Test func fullCommonTransformRotatesWorldBasisAndPreservesSensorForce() throws {
        let rotation=try UnitQuaternion(axis:Vector3(1,2,3),angle:0.7)
        let model=try ContactRangeFixtures.model(rotation:rotation),policy=try ContactRangeFixtures.policy()
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a"),ContactRangeFixtures.recipe("b",body:"b")]
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:1)
        let binding=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair(friction:true),issued:true)
        let mount=try ContactRangeFixtures.mount("b")
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision(),contact=try ContactRangeFixtures.contact()
        let result=try ReferenceContactRangeObserver().tactile(scene:scene,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
        #expect(try ContactRangeFixtures.close(result.basis.firstTangent,rotation.rotating(.unitY)))
        #expect(try ContactRangeFixtures.close(result.force,Vector3(10,-1,0)))
        #expect(try ContactRangeFixtures.close(result.couple,Vector3(0,0,0.495)))
        #expect(result.response.acceptedHistory == binding.accepted)
    }
}
