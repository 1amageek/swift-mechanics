import SwiftMechanics
import Testing

@Suite(.timeLimit(.minutes(1)))
struct ContactRangeFailureTests {
    @Test func genuineForeignGeometryAndFullMountSuccessCannotPublish() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipe=try ContactRangeFixtures.recipe("target",body:"b",shape:.sphere(radius:1))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[recipe],x:3)
        let ray=try CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10)
        for observer in [ReferenceContactRangeObserver(discovery:FaultRangeDiscovery(.foreignPose)),ReferenceContactRangeObserver(kinematics:ForeignMountedObserver())] {
            var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
            do throws(ContactRangeObservationError) {
                _=try observer.range(scene:scene,mount:mount,ray:ray,targets:[recipe.colliderID],policy:policy,collisionWork:&collision,work:&work)
                Issue.record("Foreign successful physical source published")
            } catch { if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong refusal") } }
            #expect(work.operations > 0)
        }
    }
    @Test func zeroAndPrechargedCollisionCallbackResetSuccessFailureAndBudgetReject() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipe=try ContactRangeFixtures.recipe("target",body:"b",shape:.sphere(radius:1))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[recipe],x:3),ray=try CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10)
        for seed in [0,55] {
            for mode in [FaultRangeDiscovery.Mode.resetSuccess,.resetFailure,.budgetReplacement] {
                var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision();try collision.charge(seed)
                let observer=ReferenceContactRangeObserver(discovery:FaultRangeDiscovery(mode))
                do throws(ContactRangeObservationError) {
                    _=try observer.range(scene:scene,mount:mount,ray:ray,targets:[recipe.colliderID],policy:policy,collisionWork:&collision,work:&work)
                    Issue.record("Replaced collision ledger published")
                } catch { if case .supplierLedgerReplaced=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Wrong refusal") } }
                #expect(collision.operations == seed+1)
            }
        }
    }
    @Test func zeroAndPrechargedCurrentResetSuccessFailureAndForeignForceReject() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount("b")
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a"),ContactRangeFixtures.recipe("b",body:"b")]
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes),binding=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair())
        for seed in [0,55] {
            for mode in [FaultCurrentSampler.Mode.resetSuccess,.resetFailure,.foreignSeparation] {
                var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision(),contact=try ContactRangeFixtures.contact()
                try contact.consume(operations:seed,scalarStorage:0,records:0)
                let observer=ReferenceContactRangeObserver(current:FaultCurrentSampler(mode:mode))
                do throws(ContactRangeObservationError) {
                    _=try observer.tactile(scene:scene,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work)
                    Issue.record("Invalid current supplier published")
                } catch {
                    if mode == .foreignSeparation { if case .invalidSupplierEvidence=error {} else { Issue.record("Wrong refusal") } }
                    else { if case .supplierLedgerReplaced=error {} else { Issue.record("Wrong refusal") } }
                }
                if mode != .foreignSeparation { #expect(contact.operations == seed+1) }
                else { #expect(contact.operations > seed+1) }
            }
        }
    }
    @Test func historyTimeMaterialChartLimitsAndDuplicateIdentitiesReject() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount("b")
        let recipes=try [ContactRangeFixtures.recipe("a",body:"a"),ContactRangeFixtures.recipe("b",body:"b")]
        let scene=try ContactRangeFixtures.scene(model:model,recipes:recipes),binding=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair())
        let later=try ContactRangeFixtures.scene(model:model,recipes:recipes,time:1)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision(),contact=try ContactRangeFixtures.contact()
        let observer=ReferenceContactRangeObserver()
        #expect(throws:ContactRangeObservationError.self) { try ReferenceContactRangeObserver(geometry:ForeignWitnessGeometry()).tactile(scene:scene,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work) }
        #expect(throws:ContactRangeObservationError.self) { try observer.tactile(scene:later,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work) }
        let parallel=try ContactRangeFixtures.binding(scene:scene,pair:ContactRangeFixtures.pair(),tangent:.unitX)
        #expect(throws:ContactRangeObservationError.self) { try observer.tactile(scene:scene,mount:mount,contact:parallel,policy:policy,collisionWork:&collision,contactWork:&contact,work:&work) }
        let limited=try ContactRangeFixtures.policy(hits:0)
        let ray=try CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10)
        // The sensor is on body B, so its forward ray exits B's sphere; A is behind it.
        #expect(throws:ContactRangeObservationError.self) { try observer.range(scene:scene,mount:mount,ray:ray,targets:[recipes[1].colliderID],policy:limited,collisionWork:&collision,work:&work) }
        #expect(throws:ContactRangeObservationError.self) { try observer.range(scene:scene,mount:mount,ray:ray,targets:[recipes[0].colliderID,recipes[0].colliderID],policy:policy,collisionWork:&collision,work:&work) }
        #expect(throws:ContactRangeObservationError.self) { try ContactRangeFixtures.scene(model:model,recipes:[recipes[0],recipes[0]]) }
        var storage=try ContactRangeFixtures.work(storage:95)
        #expect(throws:ContactRangeObservationError.self) { try observer.range(scene:scene,mount:mount,ray:ray,targets:[],policy:policy,collisionWork:&collision,work:&storage) }
        var noContact=try ContactRangeFixtures.contact(records:0)
        #expect(throws:ContactRangeObservationError.self) { try observer.tactile(scene:scene,mount:mount,contact:binding,policy:policy,collisionWork:&collision,contactWork:&noContact,work:&work) }
    }
    @Test func originalSupplierFailureRetainsWorkAndCannotBecomeMiss() throws {
        let model=try ContactRangeFixtures.model(),policy=try ContactRangeFixtures.policy(),mount=try ContactRangeFixtures.mount()
        let recipe=try ContactRangeFixtures.recipe("target",body:"b",shape:.sphere(radius:1))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[recipe],x:3),ray=try CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        do throws(ContactRangeObservationError) {
            _=try ReferenceContactRangeObserver(discovery:FaultRangeDiscovery(.plainFailure)).range(scene:scene,mount:mount,ray:ray,targets:[recipe.colliderID],policy:policy,collisionWork:&collision,work:&work)
            Issue.record("Supplier failure became a miss")
        } catch { if case .collisionSupplier=error { #expect(error.failedSupplierWorkUnavailable) } else { Issue.record("Wrong refusal") } }
        #expect(collision.operations > 1)
    }
    @available(macOS 15.0,iOS 18.0,tvOS 18.0,watchOS 11.0,*)
    @Test func cancellationAfterRealOpaqueQueryCannotPublish() throws {
        let model=try ContactRangeFixtures.model(),mount=try ContactRangeFixtures.mount(),token=ContactRangeCancellation()
        let original=try ContactRangeFixtures.policy()
        let policy=try ContactRangeObservationPolicy(observation:ObservationPolicy(maximumBodies:4,maximumCoordinates:6,maximumReactionRows:0,maximumMetadataBytes:1000,isCancelled:{ token.isCancelled }),
            query:original.query,contact:original.contact,maximumColliders:4,maximumHits:4,maximumTactileBindings:1,maximumTriggerRecords:8,maximumMetadataBytes:1000)
        let recipe=try ContactRangeFixtures.recipe("target",body:"b",shape:.sphere(radius:1))
        let scene=try ContactRangeFixtures.scene(model:model,recipes:[recipe],x:3),ray=try CollisionRay(origin:.zero,direction:.unitX,maximumDistance:10)
        var work=try ContactRangeFixtures.work(),collision=try ContactRangeFixtures.collision()
        do throws(ContactRangeObservationError) {
            _=try ReferenceContactRangeObserver(discovery:FaultRangeDiscovery(.cancel,cancel:{ token.cancel() })).range(scene:scene,mount:mount,ray:ray,targets:[recipe.colliderID],policy:policy,collisionWork:&collision,work:&work)
            Issue.record("Cancelled real query published")
        } catch { if case .cancelled=error {} else { Issue.record("Wrong refusal") } }
        #expect(collision.operations > 1 && token.isCancelled)
    }
}
