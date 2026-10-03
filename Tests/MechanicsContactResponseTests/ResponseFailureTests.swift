import MechanicsCore
import MechanicsModel
import MechanicsNumerics
import MechanicsDynamics
import MechanicsCollision
import MechanicsContactLaws
import MechanicsComplementarity
import MechanicsContactResponse
import Testing
@Suite(.timeLimit(.minutes(1)))
struct ResponseFailureTests {
    private func changed(_ input: ContactResponseInput, collision: CollisionSnapshot?=nil,
                         contacts: [WitnessContact]?=nil, collisionRevision: UInt64?=nil, modelRevision: UInt64?=nil) throws -> ContactResponseInput {
        try ContactResponseInput(system:input.system,collision:collision ?? input.collision,expectedCollisionRevision:collisionRevision ?? input.expectedCollisionRevision,
            expectedModelRevision:modelRevision ?? input.expectedModelRevision,contacts:contacts ?? input.contacts,driveForce:input.driveForce,timeStep:input.timeStep)
    }
    private func binding(_ old: WitnessContact, basis: ContactBasis?=nil, placement: RigidTransform?=nil, layout: UInt64?=nil) -> WitnessContact {
        WitnessContact(coordinateID:old.coordinateID,tangentLayoutRevision:layout ?? old.tangentLayoutRevision,witness:old.witness,
            firstProxyIndex:old.firstProxyIndex,secondProxyIndex:old.secondProxyIndex,firstColliderToBody:placement ?? old.firstColliderToBody,
            secondColliderToBody:old.secondColliderToBody,basis:basis ?? old.basis,pair:old.pair,accepted:old.accepted)
    }
    @Test func staleCollisionModelPlacementBasisAndHistory() throws {
        let input=try ResponseFixtures.input()
        #expect(throws:ContactResponseError.staleCollision) { try ResponseFixtures.solve(changed(input,collisionRevision:2)) }
        #expect(throws:ContactResponseError.staleModel) { try ResponseFixtures.solve(changed(input,modelRevision:2)) }
        let vetoed=try ResponseFixtures.proxy("ground-collider",body:"ground",pose:input.collision.proxies[0].pose,mask:0)
        let vetoedCollision=try CollisionSnapshot(proxies:[vetoed,input.collision.proxies[1]],revision:1)
        #expect(throws:ContactResponseError.ineligiblePair) { try ResponseFixtures.solve(changed(input,collision:vetoedCollision)) }
        let moved=try input.collision.proxies[1].moved(to:RigidTransform(rotation:.identity,translation:Vector3(0,0,1)))
        let collision=try CollisionSnapshot(proxies:[input.collision.proxies[0],moved],revision:1)
        #expect(throws:ContactResponseError.stalePose) { try ResponseFixtures.solve(changed(input,collision:collision)) }
        let placement=RigidTransform(rotation:.identity,translation:try Vector3(1,0,0))
        #expect(throws:ContactResponseError.stalePose) { try ResponseFixtures.solve(changed(input,contacts:[binding(input.contacts[0],placement:placement)])) }
        #expect(throws:ContactResponseError.staleHistory) { try ResponseFixtures.solve(changed(input,contacts:[binding(input.contacts[0],layout:2)])) }
        let basis=try ContactBasis(frame:input.contacts[0].basis.frame,contactToQuery:UnitQuaternion(axis:.unitY,angle:0.3))
        #expect(throws:ContactResponseError.invalidWitness) { try ResponseFixtures.solve(changed(input,contacts:[binding(input.contacts[0],basis:basis)])) }
        let otherFrame=ModelReference(id:try ResponseFixtures.id(.frame,"other"),revision:1)
        #expect(throws:ContactResponseError.frameMismatch) { try ResponseFixtures.solve(changed(input,contacts:[binding(input.contacts[0],basis:ContactBasis(frame:otherFrame,contactToQuery:.identity))])) }
    }
    @Test func unsupportedSelectedLawFailsBeforeMassResponse() throws {
        let friction=ContactFrictionLaw.elasticCoulomb(try ContactFrictionParameters(staticFirst:0.8,staticSecond:0.8,dynamicFirst:0.4,dynamicSecond:0.4,tangentialStiffness:1000,transitionSpeed:0.1))
        let service:any CoupledContactResponding=ImplicitLinearNormalResponse()
        for input in try [ResponseFixtures.input(damping:10),ResponseFixtures.input(friction:friction)] {
            var outer=try ResponseFixtures.work(), dynamics=try ResponseFixtures.work(), cone=try ResponseFixtures.work(), law=try ResponseFixtures.lawWork()
            let policy=try ResponseFixtures.policy()
            #expect(throws:ContactResponseError.unsupportedLaw) { try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law) }
            #expect(dynamics.operations == 0 && cone.operations == 0 && law.operations == 0)
        }
    }
    @Test func looseNumericalAcceptanceCannotBypassOriginalNormalLaw() throws {
        let input=try ResponseFixtures.input(), policy=try ResponseFixtures.policy(looseCone:true)
        do { _=try ResponseFixtures.solve(input,policy:policy); Issue.record("Original physical law must reject a zero numerical iterate") }
        catch {
            guard case ContactResponseError.originalResidual(phase:.normalLaw,let value,let threshold)=error else { Issue.record("Expected original law failure: \(error)"); return }
            #expect(value > threshold)
        }
    }
    @Test func eachResourceLedgerAndFailedSupplierRemainExplicit() throws {
        let input=try ResponseFixtures.input(), service:any CoupledContactResponding=ImplicitLinearNormalResponse(), policy=try ResponseFixtures.policy()
        var outer=try ResponseFixtures.work(operations:0), dynamics=try ResponseFixtures.work(), cone=try ResponseFixtures.work(), law=try ResponseFixtures.lawWork()
        #expect(throws:ContactResponseError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:0))) { try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law) }
        #expect(dynamics.operations == 0)
        outer=try ResponseFixtures.work(storage:1)
        #expect(throws:ContactResponseError.numerical(.resourceLimit(resource:.scalarStorage,limit:1))) { try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law) }
        outer=try ResponseFixtures.work(); dynamics=try ResponseFixtures.work(storage:1)
        #expect(throws:ContactResponseError.dynamics(.numerical(.resourceLimit(resource:.scalarStorage,limit:1),failedSupplierWorkUnavailable:false))) {
            try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law)
        }
        #expect(outer.operations > 0 && cone.operations == 0)
        outer=try ResponseFixtures.work(); dynamics=try ResponseFixtures.work(); cone=try ResponseFixtures.work(iterations:0)
        #expect(throws:ContactResponseError.complementarity(.numerical(.resourceLimit(resource:.iterations,limit:0)),failedSupplierWorkUnavailable:true)) {
            try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law)
        }
        #expect(dynamics.operations > 0 && outer.operations > 0 && cone.operations == 0)
        outer=try ResponseFixtures.work(); dynamics=try ResponseFixtures.work(); cone=try ResponseFixtures.work(); law=try ResponseFixtures.lawWork(operations:0)
        #expect(throws:ContactResponseError.law(.resourceLimit(resource:.operations,limit:0))) {
            try service.solve(input,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law)
        }
        #expect(cone.operations > 0 && law.operations == 0 && input.contacts[0].accepted.sequence == 0)
    }
    @Test func capacityCancellationAndBoundedMetadata() throws {
        let input=try ResponseFixtures.input(duplicate:true)
        #expect(throws:ContactResponseError.capacityExceeded) { try ResponseFixtures.solve(input,policy:ResponseFixtures.policy(contacts:1)) }
        #expect(throws:ContactResponseError.cancelled) { try ResponseFixtures.solve(input,policy:ResponseFixtures.policy(cancelled:true)) }
        let single=try ResponseFixtures.input(), original=single.collision.proxies[0]
        let long=try ResponseFixtures.proxy(String(repeating:"a",count:10000),body:"ground",pose:original.pose)
        let collision=try CollisionSnapshot(proxies:[long,single.collision.proxies[1]],revision:1)
        let request=try changed(single,collision:collision), policy=try ResponseFixtures.policy()
        var outer=try ResponseFixtures.work(operations:200), dynamics=try ResponseFixtures.work(), cone=try ResponseFixtures.work(), law=try ResponseFixtures.lawWork()
        let service:any CoupledContactResponding=ImplicitLinearNormalResponse()
        #expect(throws:ContactResponseError.numerical(.resourceLimit(resource:.arithmeticOperations,limit:200))) {
            try service.solve(request,policy:policy,responseWork:&outer,dynamicsWork:&dynamics,coneWork:&cone,lawWork:&law)
        }
        #expect(outer.operations <= 200 && dynamics.operations == 0)
    }
}
