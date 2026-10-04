import SwiftMechanics
import Testing
struct GranularFailureTests {
    @Test func invalidParticlesAndUnsupportedShapesAreTyped() throws {
        let proxy=try GranularFixtures.proxy("p",shape:.sphere(radius:0.5),position:.zero)
        do { _=try GranularParticle(proxy:proxy,body:GranularFixtures.ref("p",.body),material:GranularFixtures.ref("m",.material),mass:0); Issue.record("Invalid mass") }
        catch let error as GranularError { guard case .invalidInput=error else { Issue.record("Wrong failure"); return } }
        let box=try GranularFixtures.proxy("box",shape:.box(halfExtents:Vector3(1,1,1)),position:.zero)
        do { _=try GranularParticle(proxy:box,body:GranularFixtures.ref("box",.body),material:GranularFixtures.ref("m",.material),mass:1); Issue.record("Unsupported particle") }
        catch let error as GranularError { guard case .unsupportedDomain=error else { Issue.record("Wrong failure"); return } }
    }
    @Test func selectedInstantaneousImpactLawIsNotSilentlySubstituted() throws {
        do { _=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0)),GranularMotion(position:Vector3(0.49,0,0))],
            loss:.separateImpact(restitution:0.5,thresholdSpeed:0)); Issue.record("Expected selected-law failure") }
        catch let error as GranularError { guard case .unsupportedDomain=error else { Issue.record("Wrong selected-law failure"); return } }
    }
    @Test func staleCheckpointOwnerFailsEvenForEqualLayouts() throws {
        let a=try GranularFixtures.prepare(motions:[GranularMotion(position:.zero)])
        let b=try GranularFixtures.prepare(motions:[GranularMotion(position:.zero)])
        var work=try GranularFixtures.numerical(); let service: any GranularCheckpointing=ValueGranularCheckpoints()
        let checkpoint=try service.capture(a,policy:GranularFixtures.policy(),work:&work)
        do { _=try service.restore(checkpoint,model:b.model,policy:GranularFixtures.policy(),work:&work); Issue.record("Expected stale owner") }
        catch let error as GranularError { guard case .staleCheckpoint=error else { Issue.record("Wrong failure"); return } }
    }
    @Test func resourceAndCancellationBoundariesPrecedePublication() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0)),GranularMotion(position:Vector3(0.49,0,0))])
        for kind in 0..<5 {
            var workspace=GranularWorkspace(), n=try GranularFixtures.numerical(operations:kind == 0 ? 0 : 100000,storage:kind == 1 ? 0 : 10000,iterations:kind == 2 ? 0 : 100),
                c=try GranularFixtures.contactWork(), q=try GranularFixtures.collisionWork(), s=try GranularFixtures.supplier(kind == 3 ? 0 : 100)
            do { _=try ReferenceGranularEvolution().step(accepted:state,timeStepSeconds:0.001,gravity:.zero,policy:GranularFixtures.policy(cancel:{ kind == 4 }),workspace:&workspace,
                numericalWork:&n,collisionWork:&q,contactWork:&c,supplierWork:&s); Issue.record("Expected resource/cancellation failure") }
            catch let error as GranularError {
                switch error { case .numerical(.resourceLimit), .capacity(resource:"supplierCalls",limit:0), .cancelled: break; default: Issue.record("Wrong resource failure") }
            }
            #expect(state.contacts[0].history.sequence == 0 && state.steps == 0)
        }
    }
    @Test func contactCapacityAndCompleteGraphAreAdmissionContracts() throws {
        let motions=[GranularMotion(position:try Vector3(-0.49,0,0)),GranularMotion(position:try Vector3(0.49,0,0))]
        do { _=try GranularFixtures.prepare(motions:motions,policy:GranularFixtures.policy(contacts:0)); Issue.record("Expected history capacity") }
        catch let error as GranularError { guard case .capacity(resource:"contacts",limit:0)=error else { Issue.record("Wrong failure"); return } }
        let p=try GranularParticle(proxy:GranularFixtures.proxy("p",shape:.sphere(radius:0.5),position:.zero),body:GranularFixtures.ref("p",.body),material:GranularFixtures.ref("m",.material),mass:1)
        var n=try GranularFixtures.numerical(), c=try GranularFixtures.contactWork(), s=try GranularFixtures.supplier()
        do { _=try ReferenceGranularPreparation().prepare(revision:1,frame:GranularFixtures.ref("world",.frame),particles:[p],boundaries:[],laws:[GranularFixtures.pair("m","other")],
            motions:[GranularMotion(position:.zero)],random:RuntimeRandomState(seed:1),timeSeconds:0,policy:GranularFixtures.policy(),numericalWork:&n,contactWork:&c,supplierWork:&s); Issue.record("Expected extra binding failure") }
        catch let error as GranularError { guard case .invalidBinding=error else { Issue.record("Wrong failure"); return } }
    }
    @Test func actualFailedLawRetainsCauseConsumptionAndStopsOnce() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.2,0,0)),GranularMotion(position:Vector3(0.2,0,0))])
        var workspace=GranularWorkspace(), n=try GranularFixtures.numerical(), c=try GranularFixtures.contactWork(),q=try GranularFixtures.collisionWork(),s=try GranularFixtures.supplier()
        do { _=try ReferenceGranularEvolution().step(accepted:state,timeStepSeconds:0.001,gravity:.zero,policy:GranularFixtures.policy(),workspace:&workspace,
            numericalWork:&n,collisionWork:&q,contactWork:&c,supplierWork:&s); Issue.record("Expected normal domain failure") }
        catch let error as GranularError { guard case .contact(.normalDomain,failedSupplierWorkUnavailable:false)=error else { Issue.record("Wrong cause/work availability"); return } }
        #expect(s.calls == 2 && c.operations >= 4096 && q.operations >= 4096)
        #expect(state.timeSeconds == 0)
    }
    @Test func supplierLedgerResetFailsWithUnknownWorkAndPreservesPriorLedger() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0)),GranularMotion(position:Vector3(0.49,0,0))])
        var workspace=GranularWorkspace(), n=try GranularFixtures.numerical(), c=try GranularFixtures.contactWork(),q=try GranularFixtures.collisionWork(),s=try GranularFixtures.supplier()
        try c.consume(operations:17,scalarStorage:0,records:0)
        do { _=try ReferenceGranularEvolution(law:ResettingGranularLaw()).step(accepted:state,timeStepSeconds:0.001,gravity:.zero,policy:GranularFixtures.policy(),workspace:&workspace,
            numericalWork:&n,collisionWork:&q,contactWork:&c,supplierWork:&s); Issue.record("Expected ledger violation") }
        catch let error as GranularError { guard case .invalidSupplierLedger(supplier:"contact")=error else { Issue.record("Wrong failure"); return } }
        #expect(c.operations == 17 && s.calls == 2)
    }
    @Test func actualSupplierBudgetFailureIsNotSuccessfulZeroContact() throws {
        let state=try GranularFixtures.prepare(motions:[GranularMotion(position:Vector3(-0.49,0,0)),GranularMotion(position:Vector3(0.49,0,0))])
        var workspace=GranularWorkspace(), n=try GranularFixtures.numerical(), c=try GranularFixtures.contactWork(),q=try GranularFixtures.collisionWork(operations:0),s=try GranularFixtures.supplier()
        do { _=try ReferenceGranularEvolution().step(accepted:state,timeStepSeconds:0.001,gravity:.zero,policy:GranularFixtures.policy(),workspace:&workspace,
            numericalWork:&n,collisionWork:&q,contactWork:&c,supplierWork:&s); Issue.record("Expected supplier limit") }
        catch let error as GranularError { guard case .collision(.resourceLimit(resource:.operations,limit:0),failedSupplierWorkUnavailable:false)=error else { Issue.record("Wrong failure"); return } }
        #expect(s.calls == 1 && c.operations == 0)
    }
    @Test func longMetadataIsChargedBeforeUnboundedEqualityOrSupplierInvocation() throws {
        let key=String(repeating:"x",count:20000), proxy=try GranularFixtures.proxy(key,shape:.sphere(radius:0.5),position:.zero)
        let p=try GranularParticle(proxy:proxy,body:GranularFixtures.ref(key,.body),material:GranularFixtures.ref("m",.material),mass:1)
        var n=try GranularFixtures.numerical(operations:1000),c=try GranularFixtures.contactWork(),s=try GranularFixtures.supplier()
        do { _=try ReferenceGranularPreparation().prepare(revision:1,frame:GranularFixtures.ref("world",.frame),particles:[p],boundaries:[],laws:[],motions:[GranularMotion(position:.zero)],
            random:RuntimeRandomState(seed:1),timeSeconds:0,policy:GranularFixtures.policy(),numericalWork:&n,contactWork:&c,supplierWork:&s); Issue.record("Expected metadata limit") }
        catch let error as GranularError { guard case .numerical(.resourceLimit(resource:.arithmeticOperations,limit:1000))=error else { Issue.record("Wrong failure"); return } }
        #expect(s.calls == 0 && n.operations <= 1000)
    }
}
